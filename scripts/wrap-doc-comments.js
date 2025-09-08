#!/usr/bin/env node

// A script to wrap doc comments in #if !no_backend_docs ... #end directives

const fs = require('fs');
const path = require('path');

// Configuration
const baseDir = path.join(__dirname, '..');
const directories = [
    path.join(baseDir, 'plugins/headless/runtime/src/backend'),
    path.join(baseDir, 'plugins/unity/runtime/src/backend')
];

let totalFilesProcessed = 0;
let totalCommentsWrapped = 0;

// Helper function to recursively get all .hx files
function getHaxeFiles(dir) {
    const files = [];

    function walkDir(currentDir) {
        const entries = fs.readdirSync(currentDir, { withFileTypes: true });

        for (const entry of entries) {
            const fullPath = path.join(currentDir, entry.name);

            if (entry.isDirectory()) {
                walkDir(fullPath);
            } else if (entry.isFile() && entry.name.endsWith('.hx')) {
                files.push(fullPath);
            }
        }
    }

    if (fs.existsSync(dir)) {
        walkDir(dir);
    }

    return files;
}

// Process a single file
function processFile(filePath) {
    const content = fs.readFileSync(filePath, 'utf8');
    const lines = content.split('\n');

    let modified = false;
    let commentsWrapped = 0;
    const processedLines = [];
    let i = 0;

    while (i < lines.length) {
        const line = lines[i];
        const trimmedLine = line.trim();

        // Check if this line starts a doc comment
        if (trimmedLine.startsWith('/**')) {
            // Get the indentation of the current line
            const indent = line.match(/^(\s*)/)[1];

            // Check if already wrapped (previous line contains #if !no_backend_docs)
            if (i > 0 && lines[i - 1].trim() === '#if !no_backend_docs') {
                processedLines.push(line);
                i++;
                continue;
            }

            // Find the end of the doc comment
            let docCommentLines = [line];
            let j = i + 1;

            // If the /** is not closed on the same line, find the closing */
            if (!line.includes('*/')) {
                while (j < lines.length && !lines[j].includes('*/')) {
                    docCommentLines.push(lines[j]);
                    j++;
                }
                if (j < lines.length) {
                    docCommentLines.push(lines[j]);
                    j++;
                }
            } else {
                j = i + 1;
            }

            // Add the wrapped doc comment
            processedLines.push(indent + '#if !no_backend_docs');
            docCommentLines.forEach(docLine => processedLines.push(docLine));
            processedLines.push(indent + '#end');

            modified = true;
            commentsWrapped++;
            i = j;
        } else {
            processedLines.push(line);
            i++;
        }
    }

    if (modified) {
        fs.writeFileSync(filePath, processedLines.join('\n'));
        console.log(`✓ ${path.relative(baseDir, filePath)} - Wrapped ${commentsWrapped} doc comment(s)`);
        totalCommentsWrapped += commentsWrapped;
    }

    return modified;
}

// Main execution
console.log('Wrapping doc comments in backend files...\n');

for (const dir of directories) {
    if (!fs.existsSync(dir)) {
        console.log(`⚠ Directory not found: ${path.relative(baseDir, dir)}`);
        continue;
    }

    console.log(`Processing directory: ${path.relative(baseDir, dir)}`);

    const files = getHaxeFiles(dir);
    console.log(`  Found ${files.length} Haxe files`);

    for (const file of files) {
        processFile(file);
        totalFilesProcessed++;
    }

    console.log('');
}

console.log(`\nSummary:`);
console.log(`  Total files processed: ${totalFilesProcessed}`);
console.log(`  Total doc comments wrapped: ${totalCommentsWrapped}`);