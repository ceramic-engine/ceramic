using System;
using System.Collections.Generic;

namespace Demo
{
    /// <summary>Doc comment.</summary>
    public sealed class Counter<T> where T : IComparable<T>
    {
        private readonly List<T> _items = new();
        public int Count => _items.Count;

        public async Task<bool> AddAsync(T item)
        {
            _items.Add(item);
            Console.WriteLine($"Added {item} ({Count})");
            return await Task.FromResult(true);
        }
    }
}
