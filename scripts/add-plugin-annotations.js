#!/usr/bin/env node

// A script to add @:plugin('name') to fields that are surrounded with #if plugin_name ... #end

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
let totalAnnotationsAdded = 0;

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
    let annotationsAdded = 0;
    const newLines = [];

    let currentPlugin = null;
    let indentStack = [];

    // Check if this file belongs to a plugin
    const pluginMatch = filePath.match(/\/plugins\/(\w+)\/runtime\//);
    const filePlugin = pluginMatch ? pluginMatch[1] : null;

    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        const trimmedLine = line.trim();

        // Check for #if plugin_* directive
        const pluginMatch = trimmedLine.match(/^#if\s+plugin_(\w+)/);
        if (pluginMatch) {
            currentPlugin = pluginMatch[1];
            indentStack.push({ plugin: currentPlugin, line: i });
            newLines.push(line);
            continue;
        }

        // Check for #end directive
        if (trimmedLine === '#end') {
            if (indentStack.length > 0) {
                indentStack.pop();
                currentPlugin = indentStack.length > 0 ? indentStack[indentStack.length - 1].plugin : null;
            }
            newLines.push(line);
            continue;
        }

        // If we're inside a plugin block
        if (currentPlugin) {
            // Check if this line declares a field (variable or method)
            const fieldMatch = line.match(/^\s*((?:@\w+(?:\([^)]*\))?\s*)*)(public|private|static|override|inline|extern|macro|dynamic|final).*(?:var|function)\s+(\w+)/);

            if (fieldMatch) {
                const fieldName = fieldMatch[3];

                // Skip getter and setter functions
                if (fieldName.startsWith('get_') || fieldName.startsWith('set_')) {
                    newLines.push(line);
                    continue;
                }

                // Skip if file belongs to the same plugin as the #if directive
                if (filePlugin && filePlugin === currentPlugin) {
                    newLines.push(line);
                    continue;
                }

                const indent = line.match(/^\s*/)[0];
                const existingAnnotations = fieldMatch[1] || '';

                // Check previous lines for @:plugin annotation
                let hasPluginAnnotation = false;
                for (let j = newLines.length - 1; j >= 0 && j >= newLines.length - 5; j--) {
                    const prevLine = newLines[j].trim();
                    if (prevLine.match(/^@:plugin\s*\(/)) {
                        hasPluginAnnotation = true;
                        break;
                    }
                    // Stop checking if we hit a non-annotation line
                    if (prevLine && !prevLine.startsWith('@') && !prevLine.startsWith('//') && !prevLine.startsWith('/*') && !prevLine.startsWith('*')) {
                        break;
                    }
                }

                // Also check if @:plugin annotation exists in the current line's annotations
                const pluginAnnotationRegex = new RegExp(`@:plugin\\s*\\(\\s*['"]${currentPlugin}['"]\\s*\\)`);
                const hasSpecificPluginAnnotation = pluginAnnotationRegex.test(existingAnnotations) || hasPluginAnnotation;

                if (!hasSpecificPluginAnnotation) {
                    // Add the @:plugin annotation
                    const pluginAnnotation = `${indent}@:plugin('${currentPlugin}')`;
                    newLines.push(pluginAnnotation);
                    modified = true;
                    annotationsAdded++;
                }
            }
        }

        newLines.push(line);
    }

    if (modified) {
        fs.writeFileSync(filePath, newLines.join('\n'));
        console.log(`✓ ${path.relative(baseDir, filePath)} - Added ${annotationsAdded} annotation(s)`);
        totalAnnotationsAdded += annotationsAdded;
    }

    return modified;
}

// Main execution
console.log('Adding @:plugin annotations to Ceramic files...\n');

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
console.log(`  Total annotations added: ${totalAnnotationsAdded}`);