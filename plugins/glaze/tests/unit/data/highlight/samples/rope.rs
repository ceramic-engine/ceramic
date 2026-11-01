use std::io;
use std::ops::{Bound, RangeBounds};
use std::sync::Arc;

use crate::{
    end_bound_to_num,
    iter::{Bytes, CharIndices, Chars, Chunks},
    rope_builder::RopeBuilder,
    slice::RopeSlice,
    start_bound_to_num, str_utils,
    tree::{Children, Node, Text, TextInfo, MAX_TEXT_SIZE},
    ChunkCursor,
    Error::*,
    Result,
};

#[cfg(any(
    feature = "metric_lines_lf",
    feature = "metric_lines_lf_cr",
    feature = "metric_lines_unicode"
))]
use crate::{iter::Lines, LineType};

/// A utf8 text rope.
///
/// The time complexity of nearly all edit and query operations on `Rope` are
/// worst-case `O(log N)` in the length of the rope.  `Rope` is designed to work
/// efficiently even for huge (in the gigabytes) and pathological (all on one
/// line) texts.
///
/// # Editing Operations
///
/// The editing operations on `Rope` are insertion and removal of text.  For
/// example:
///
/// ```
/// # use ropey::Rope;
/// #
/// let mut rope = Rope::from_str("Hello みんなさん!");
/// rope.remove(6..21);
/// rope.insert(6, "world");
///
/// assert_eq!(rope, "Hello world!");
/// ```
///
/// # Query Operations
///
/// `Rope` provides a rich set of efficient query functions, including querying
/// rope length in bytes/`char`s/lines, fetching individual `char`s or lines,
/// and converting between different indexing metrics.
///
#[cfg_attr(
    feature = "metric_lines_lf_cr",
    doc = r##"
For example, to find the starting byte index of a given line:

```
# use ropey::Rope;
use ropey::LineType::LF_CR;

let rope = Rope::from_str("Hello みんなさん!\nHow are you?\nThis text has multiple lines!");

assert_eq!(rope.line_to_byte_idx(0, LF_CR), 0);
assert_eq!(rope.line_to_byte_idx(1, LF_CR), 23);
assert_eq!(rope.line_to_byte_idx(2, LF_CR), 36);
```

# Slicing

You can take immutable slices of a `Rope` using `slice()`:

```
# use ropey::Rope;
#
let mut rope = Rope::from_str("Hello みんなさん!");
let middle = rope.slice(3..12);

assert_eq!(middle, "lo みん");
```
"##
)]
///
/// # Cloning
///
/// Cloning `Rope`s is extremely cheap, running in `O(1)` time and taking a
/// small constant amount of memory for the new clone, regardless of text size.
/// This is accomplished by data sharing between `Rope` clones.  The memory used
/// by clones only grows incrementally as the their contents diverge due to
/// edits.  All of this is thread safe, so clones can be sent freely between
/// threads.
///
/// The primary intended use case for this feature is to allow asynchronous (in
/// the general sense, not necessarily in the `async` sense) processing of
/// `Rope`s.  For example, saving a large document to disk in a separate thread
/// while the user continues to perform edits.
#[derive(Clone)]
pub struct Rope {
    pub(crate) root: Node,
    pub(crate) root_info: TextInfo,

    /// Specifies the sub-range of `root` to use as this rope's
    /// contents.  Normally just set to the full range of `root`, but
    /// [`crate::extra::disconnect_slice()`] uses this to create "disconnected
    /// slices".
    pub(crate) byte_range: [usize; 2],
}

impl Rope {
    //---------------------------------------------------------
    // Constructors.

    /// Creates an empty `Rope`.
    #[inline]
    pub fn new() -> Self {
        Rope {
            root: Node::Leaf(Arc::new(Text::new())),
            root_info: TextInfo::new(),
            byte_range: [0; 2],
        }
    }

    /// Creates a `Rope` from a string slice.
    ///
    /// Runs in O(N) time.
    #[inline]
    #[allow(clippy::should_implement_trait)]
    pub fn from_str(text: &str) -> Self {
        RopeBuilder::new().build_at_once(text)
    }

    //-----------------------------------------------------------------------
    // Convenience I/O methods.

    /// Creates a `Rope` from the output of a reader.
    ///
    /// This is a convenience function, and provides *no specific guarantees*
    /// about performance or internal implementation aside from the runtime
    /// complexity listed below.
    ///
    /// When more precise control over IO behavior, buffering, etc. is desired,
    /// you should handle IO yourself and use [`RopeBuilder`] to build the
    /// `Rope`.
    ///
    /// Runs in O(N) time.
    ///
    /// # Errors
    ///
    /// - If the reader returns an error, `from_reader` stops and returns
    ///   that error.
    /// - If non-utf8 data is encountered, an IO error with kind
    ///   `InvalidData` is returned.
    ///
    /// Note: some data from the reader is likely consumed even if there is
    /// an error.
    #[allow(unused_mut)]
    pub fn from_reader<T: io::Read>(mut reader: T) -> io::Result<Self> {
        const BUFFER_SIZE: usize = crate::tree::MAX_TEXT_SIZE * 4;
        let mut builder = RopeBuilder::new();
        let mut buffer = vec![0u8; BUFFER_SIZE];
        let mut fill_idx = 0; // How much `buffer` is currently filled with valid data
        loop {
            match reader.read(&mut buffer[fill_idx..]) {
                Ok(read_count) => {
                    fill_idx += read_count;

                    // Determine how much of the buffer is valid utf8.
                    let valid_count = match std::str::from_utf8(&buffer[..fill_idx]) {
                        Ok(_) => fill_idx,
                        Err(e) => e.valid_up_to(),
                    };

                    // Append the valid part of the buffer to the rope.
                    if valid_count > 0 {
                        // The unsafe block here is reinterpreting the bytes as
                        // utf8.  This is safe because the bytes being
                        // reinterpreted have already been validated as utf8
                        // just above.
                        builder.append(unsafe {
                            std::str::from_utf8_unchecked(&buffer[..valid_count])
                        });
                    }

                    // Shift the un-read part of the buffer to the beginning.
                    if valid_count < fill_idx {
                        buffer.copy_within(valid_count..fill_idx, 0);
                    }
                    fill_idx -= valid_count;

                    if fill_idx == BUFFER_SIZE {
                        // Buffer is full and none of it could be consumed.  Utf8
                        // codepoints don't get that large, so it's clearly not
                        // valid text.
                        return Err(io::Error::new(
                            io::ErrorKind::InvalidData,
                            "stream did not contain valid UTF-8",
                        ));
                    }

                    // If we're done reading
                    if read_count == 0 {
                        if fill_idx > 0 {
                            // We couldn't consume all data.
                            return Err(io::Error::new(
                                io::ErrorKind::InvalidData,
                                "stream contained invalid UTF-8",
                            ));
                        } else {
                            return Ok(builder.finish());
                        }
                    }
                }

                Err(e) => {
                    // Read error
                    return Err(e);
                }
            }
        }
    }

    /// Writes the contents of the `Rope` to a writer.
    ///
    /// This is a convenience function, and provides *no specific guarantees*
    /// about performance or internal implementation aside from the runtime
    /// complexity listed below.
    ///
    /// When more precise control over IO behavior, buffering, etc. is
    /// desired, you should handle IO yourself and use the [`Chunks`]
    /// iterator to iterate through the `Rope`'s contents.
    ///
    /// Runs in O(N) time.
    ///
    /// # Errors
    ///
    /// - If the writer returns an error, `write_to` stops and returns that
    ///   error.
    ///
    /// Note: some data may have been written even if an error is returned.
    #[allow(unused_mut)]
    pub fn write_to<T: io::Write>(&self, mut writer: T) -> io::Result<()> {
        for chunk in self.chunks() {
            writer.write_all(chunk.as_bytes())?;
        }

        Ok(())
    }

    //-----------------------------------------------------------------------
    // Edit methods

    /// Inserts `text` at byte index `byte_idx`.
    ///
    /// Runs in O(M log N) time, where N is the length of the `Rope` and M
    /// is the length of `text`.
    ///
    /// # Example
    ///
    /// ```
    /// # use ropey::Rope;
    /// let mut rope = Rope::from_str("Hello!");
    /// rope.insert(5, " world");
    ///
    /// assert_eq!("Hello world!", rope);
    /// ```
    ///
    /// # Panics
    ///
    /// - If `byte_idx` is out of bounds (i.e. `byte_idx > len()`).
    /// - If `byte_idx` is not on a char boundary.
    #[track_caller]
    #[inline]
    pub fn insert(&mut self, byte_idx: usize, text: &str) {
        match self.try_insert(byte_idx, text) {
            Ok(_) => {}
            Err(e) => panic!("{}", e),
        }
    }

    /// Inserts a single char `ch` at byte index `byte_idx`.
    ///
    /// Runs in O(log N) time.
    ///
    /// # Example
    ///
    /// ```
    /// # use ropey::Rope;
    /// let mut rope = Rope::from_str("Hello orld!");
    /// rope.insert_char(6, 'w');
    ///
    /// assert_eq!("Hello world!", rope);
    /// ```
    ///
    /// # Panics
    ///
    /// - If `byte_idx` is out of bounds (i.e. `byte_idx > len()`).
    /// - If `byte_idx` is not on a char boundary.
    #[inline]
    pub fn insert_char(&mut self, byte_idx: usize, ch: char) {
        let mut buf = [0u8; 4];
        self.insert(byte_idx, ch.encode_utf8(&mut buf));
    }

    /// Removes the text in the given byte index range.
    ///
    /// Uses range syntax, e.g. `2..7`, `2..`, etc.
    ///
    /// Runs in O(M + log N) time, where N is the length of the `Rope` and M
    /// is the length of the range being removed.
    ///
    /// # Example
    ///
    /// ```
    /// # use ropey::Rope;
    /// let mut rope = Rope::from_str("Hello world!");
    /// rope.remove(5..);
    ///
    /// assert_eq!("Hello", rope);
    /// ```
    ///
    /// # Panics
    ///
    /// - If the start of the range is greater than the end.
    /// - If the end of the range is out of bounds (i.e. `end > len()`).
    /// - If the range ends are not on char boundaries.
    #[track_caller]
    #[inline]
    pub fn remove<R>(&mut self, byte_range: R)
    where
        R: RangeBounds<usize>,
    {
        match self.try_remove(byte_range) {
            Ok(_) => {}
            Err(e) => panic!("{}", e),
        }
    }

    /// Converts a "disconnected slice" into a proper rope, in preparation for
    /// edits.
    fn trim_disconnected_slice(&mut self) {
        let trim_range_start = [0, self.byte_range[0]];
        let trim_range_end = [self.byte_range[1], self.root_info.bytes];

        // Note: unlike with normal removal, we don't have to worry about crlf
        // splits because we know we're trimming off the ends, not removing a
        // section in the middle.
        self.remove_core_impl(trim_range_end)
            .expect("Trimming to slice range should always succeed.");
        self.remove_core_impl(trim_range_start)
            .expect("Trimming to slice range should always succeed.");

        self.byte_range[0] = 0;
        self.byte_range[1] = self.root_info.bytes;
    }

    //---------------------------------------------------------
    // Slicing.

    /// Gets an immutable slice of the `Rope`.
    ///
    /// Uses range syntax, e.g. `2..7`, `2..`, etc.
    ///
    /// # Example
    ///
    /// ```
    /// # use ropey::Rope;
    /// let rope = Rope::from_str("Hello world!");
    /// let slice = rope.slice(..5);
    ///
    /// assert_eq!("Hello", slice);
    /// ```
    ///
    /// Runs in O(log N) time.
    ///
    /// # Panics
    ///
    /// - If the start of the range is greater than the end.
    /// - If the end of the range is out of bounds (i.e. `end > len()`).
    /// - If the range ends are not on char boundaries.
    #[track_caller]
    #[inline]
    pub fn slice<R>(&self, byte_range: R) -> RopeSlice<'_>
    where
        R: RangeBounds<usize>,
    {
        match self.try_slice(byte_range) {
            Ok(slice) => slice,
            Err(e) => panic!("{}", e),
        }
    }

    //---------------------------------------------------------
    // Methods shared between Rope and RopeSlice.

    crate::shared_impl::shared_main_impl_methods!('_);

    //---------------------------------------------------------
    // Misc. internal methods.

    /// Iteratively replaces the root node with its child if it only has
    /// one child.
