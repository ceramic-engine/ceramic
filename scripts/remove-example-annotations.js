#!/usr/bin/env node

// A script to remove @example lines from doc comments while preserving the rest of the content

const fs = require('fs');
const path = require('path');

// Configuration
const baseDir = path.join(__dirname, '..');
const directories = [
    path.join(baseDir, 'runtime/src/ceramic'),
    ...fs.readdirSync(path.join(baseDir, 'plugins'))
        .filter(dir => fs.existsSync(path.join(baseDir, 'plugins', dir, 'runtime/src')))
        .map(dir => path.join(baseDir, 'plugins', dir, 'runtime/src'))
];

let totalFilesProcessed = 0;
let totalLinesRemoved = 0;

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
    let linesProcessed = 0;
    const newLines = [];

    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        
        // Check if this line contains @example
        const exampleMatch = line.match(/^(\s*\*\s*)@example\s*(.*)$/);
        if (exampleMatch) {
            const prefix = exampleMatch[1];
            const restOfLine = exampleMatch[2];
            
            if (restOfLine.trim()) {
                // If there's content after @example, keep the line but remove @example
                newLines.push(prefix + restOfLine);
                modified = true;
                linesProcessed++;
            } else {
                // If @example is alone on the line, skip the entire line
                modified = true;
                linesProcessed++;
                continue;
            }
        } else {
            // Keep all other lines as-is
            newLines.push(line);
        }
    }

    if (modified) {
        fs.writeFileSync(filePath, newLines.join('\n'));
        console.log(`✓ ${path.relative(baseDir, filePath)} - Processed ${linesProcessed} @example line(s)`);
        totalLinesRemoved += linesProcessed;
    }

    return modified;
}

// Main execution
console.log('Removing @example lines from Ceramic files...\n');

for (const dir of directories) {
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
console.log(`  Total @example lines processed: ${totalLinesRemoved}`);