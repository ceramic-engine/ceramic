#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const readline = require('readline');

// Configuration
const HAXE_DOCS_DETAILED = path.join(__dirname, '..', 'HAXE_DOCS_DETAILED.md');
const HAXE_DOCS_PROGRESS = path.join(__dirname, '..', 'HAXE_DOCS_PROGRESS.md');

// Read command line arguments
const args = process.argv.slice(2);
const command = args[0];
const filePath = args[1];

function showHelp() {
    console.log(`
Haxe Documentation Helper

Usage:
  node scripts/auto-document-haxe.js next
    - Shows the next file to document from the priority list
    
  node scripts/auto-document-haxe.js status <file>
    - Shows undocumented fields for a specific file
    
  node scripts/auto-document-haxe.js verify <file>
    - Verifies if a file is fully documented
    
  node scripts/auto-document-haxe.js progress
    - Shows overall documentation progress
    
  node scripts/auto-document-haxe.js batch <n>
    - Creates a batch of n files to document
    
Examples:
  node scripts/auto-document-haxe.js next
  node scripts/auto-document-haxe.js status runtime/src/ceramic/Entity.hx
  node scripts/auto-document-haxe.js verify runtime/src/ceramic/Entity.hx
  node scripts/auto-document-haxe.js batch 5
`);
}

// Parse the detailed documentation file
function parseDetailedDocs() {
    if (!fs.existsSync(HAXE_DOCS_DETAILED)) {
        console.error('Error: HAXE_DOCS_DETAILED.md not found. Run analyze-haxe-docs.js first.');
        process.exit(1);
    }
    
    const content = fs.readFileSync(HAXE_DOCS_DETAILED, 'utf8');
    const lines = content.split('\n');
    
    const files = [];
    let currentFile = null;
    let inFile = false;
    let inTypes = false;
    
    for (const line of lines) {
        // Check for file header
        const fileMatch = line.match(/^####\s+(.+\.hx)$/);
        if (fileMatch) {
            if (currentFile) files.push(currentFile);
            currentFile = {
                path: fileMatch[1],
                undocumentedFields: [],
                undocumentedTypes: [],
                publicFields: 0,
                documentedFields: 0
            };
            inFile = true;
            inTypes = false;
            continue;
        }
        
        // Check for undocumented types section
        if (inFile && line.includes('Undocumented types:')) {
            inTypes = true;
            continue;
        }
        
        // Parse undocumented types
        if (inTypes && line.includes('- [ ] `')) {
            const typeMatch = line.match(/- \[ \] `([^`]+)` \(line (\d+)\)/);
            if (typeMatch) {
                currentFile.undocumentedTypes.push({
                    definition: typeMatch[1],
                    line: parseInt(typeMatch[2])
                });
            }
        }
        
        // Parse field counts
        if (inFile && line.includes('Public fields:')) {
            const match = line.match(/(\d+)\/(\d+)\s+documented/);
            if (match) {
                currentFile.documentedFields = parseInt(match[1]);
                currentFile.publicFields = parseInt(match[2]);
            }
        }
        
        // Parse undocumented fields
        if (inFile && line.includes('- [ ] `')) {
            const match = line.match(/- \[ \] `([^`]+)` \(line (\d+)\): (.+)/);
            if (match) {
                currentFile.undocumentedFields.push({
                    name: match[1],
                    line: parseInt(match[2]),
                    definition: match[3]
                });
            }
        }
        
        // End of file section
        if (inFile && line.trim() === '' && currentFile && currentFile.undocumentedFields.length > 0) {
            inFile = false;
        }
    }
    
    if (currentFile) files.push(currentFile);
    
    return files;
}

// Parse progress file to get priority list
function getPriorityList() {
    const content = fs.readFileSync(HAXE_DOCS_PROGRESS, 'utf8');
    const lines = content.split('\n');
    
    const priorities = [];
    let inPrioritySection = false;
    
    for (const line of lines) {
        if (line.includes('Phase 1: Core Classes')) {
            inPrioritySection = true;
            continue;
        }
        if (line.includes('Documentation Tracking')) {
            break;
        }
        
        if (inPrioritySection) {
            const match = line.match(/^\d+\.\s+\[\s*\]\s+(.+\.hx)\s+-\s+(\d+)/);
            if (match) {
                priorities.push({
                    path: match[1],
                    undocumentedCount: parseInt(match[2]),
                    completed: false
                });
            }
            const completedMatch = line.match(/^\d+\.\s+\[x\]\s+(.+\.hx)/);
            if (completedMatch) {
                priorities.push({
                    path: completedMatch[1],
                    completed: true
                });
            }
        }
    }
    
    return priorities;
}

// Command: next
function showNext() {
    const priorities = getPriorityList();
    const files = parseDetailedDocs();
    
    for (const priority of priorities) {
        if (!priority.completed) {
            const file = files.find(f => f.path === priority.path);
            if (file && file.undocumentedFields.length > 0) {
                console.log(`\nNext file to document: ${file.path}`);
                console.log(`Undocumented public fields: ${file.undocumentedFields.length}`);
                console.log(`\nFirst 10 undocumented fields:`);
                
                for (let i = 0; i < Math.min(10, file.undocumentedFields.length); i++) {
                    const field = file.undocumentedFields[i];
                    console.log(`  - ${field.name} (line ${field.line})`);
                }
                
                console.log(`\nTo see all fields, run:`);
                console.log(`  node scripts/auto-document-haxe.js status ${file.path}`);
                return;
            }
        }
    }
    
    console.log('All priority files are documented! Check HAXE_DOCS_DETAILED.md for more files.');
}

// Command: status
function showStatus(filePath) {
    const files = parseDetailedDocs();
    const file = files.find(f => f.path === filePath || f.path.endsWith(filePath));
    
    if (!file) {
        console.log(`File not found in documentation analysis: ${filePath}`);
        console.log('Run analyze-haxe-docs.js to update the analysis.');
        return;
    }
    
    console.log(`\nFile: ${file.path}`);
    
    // Show undocumented types first
    if (file.undocumentedTypes && file.undocumentedTypes.length > 0) {
        console.log(`\n⚠️ Undocumented types (${file.undocumentedTypes.length}):`);
        for (const type of file.undocumentedTypes) {
            console.log(`  Line ${type.line}: ${type.definition}`);
        }
    }
    
    console.log(`\nPublic fields: ${file.documentedFields}/${file.publicFields} documented`);
    console.log(`Completion: ${((file.documentedFields / file.publicFields) * 100).toFixed(1)}%`);
    
    if (file.undocumentedFields.length > 0) {
        console.log(`\nUndocumented fields (${file.undocumentedFields.length}):`);
        for (const field of file.undocumentedFields) {
            console.log(`  Line ${field.line}: ${field.name}`);
            console.log(`    Definition: ${field.definition}`);
        }
    } else if (!file.undocumentedTypes || file.undocumentedTypes.length === 0) {
        console.log('\n✅ File is fully documented!');
    }
}

// Command: verify
function verifyFile(filePath) {
    // Re-run analysis for this specific file
    const fullPath = filePath.startsWith('/') ? filePath : path.join(process.cwd(), filePath);
    
    if (!fs.existsSync(fullPath)) {
        console.error(`File not found: ${fullPath}`);
        return;
    }
    
    console.log(`Verifying documentation for: ${filePath}`);
    console.log('Re-running analysis...');
    
    // Run the analysis script
    const { execSync } = require('child_process');
    try {
        execSync('node scripts/analyze-haxe-docs.js', { stdio: 'pipe' });
    } catch (e) {
        console.error('Error running analysis:', e.message);
        return;
    }
    
    // Check the results
    showStatus(filePath);
}

// Command: progress
function showProgress() {
    const files = parseDetailedDocs();
    
    let totalPublic = 0;
    let totalDocumented = 0;
    let totalTypes = 0;
    let undocumentedTypes = 0;
    let fullyDocumented = 0;
    let partiallyDocumented = 0;
    let undocumented = 0;
    
    for (const file of files) {
        totalPublic += file.publicFields;
        totalDocumented += file.documentedFields;
        
        if (file.undocumentedTypes) {
            undocumentedTypes += file.undocumentedTypes.length;
        }
        
        const hasUndocumentedTypes = file.undocumentedTypes && file.undocumentedTypes.length > 0;
        const hasUndocumentedFields = file.undocumentedFields && file.undocumentedFields.length > 0;
        
        if (!hasUndocumentedTypes && !hasUndocumentedFields && file.publicFields > 0) {
            fullyDocumented++;
        } else if (file.documentedFields > 0) {
            partiallyDocumented++;
        } else if (file.publicFields > 0) {
            undocumented++;
        }
    }
    
    console.log('\n📊 Documentation Progress\n');
    
    if (undocumentedTypes > 0) {
        console.log(`⚠️ Undocumented types (classes/enums/etc): ${undocumentedTypes}\n`);
    }
    
    console.log(`Total public fields: ${totalPublic}`);
    console.log(`Documented fields: ${totalDocumented} (${((totalDocumented/totalPublic)*100).toFixed(1)}%)`);
    console.log(`Remaining fields: ${totalPublic - totalDocumented}\n`);
    
    console.log(`Files:`);
    console.log(`  ✅ Fully documented: ${fullyDocumented}`);
    console.log(`  ⚠️  Partially documented: ${partiallyDocumented}`);
    console.log(`  ❌ Undocumented: ${undocumented}`);
    console.log(`  Total: ${files.length}`);
    
    // Show top files needing work
    const needsWork = files
        .filter(f => f.undocumentedFields.length > 0)
        .sort((a, b) => b.undocumentedFields.length - a.undocumentedFields.length)
        .slice(0, 10);
    
    console.log('\n📝 Top 10 files needing documentation:');
    for (const file of needsWork) {
        const percent = file.publicFields > 0 
            ? ((file.documentedFields / file.publicFields) * 100).toFixed(0)
            : '0';
        console.log(`  ${file.path}`);
        console.log(`    ${file.undocumentedFields.length} fields to document (${percent}% complete)`);
    }
}

// Command: batch
function createBatch(count) {
    const n = parseInt(count) || 5;
    const priorities = getPriorityList();
    const files = parseDetailedDocs();
    
    console.log(`\n📦 Documentation Batch (${n} files)\n`);
    
    let batchCount = 0;
    let totalFields = 0;
    
    for (const priority of priorities) {
        if (batchCount >= n) break;
        if (!priority.completed) {
            const file = files.find(f => f.path === priority.path);
            if (file && file.undocumentedFields.length > 0) {
                batchCount++;
                totalFields += file.undocumentedFields.length;
                
                console.log(`${batchCount}. ${file.path}`);
                console.log(`   ${file.undocumentedFields.length} fields to document`);
                console.log(`   First few: ${file.undocumentedFields.slice(0, 3).map(f => f.name).join(', ')}`);
                console.log('');
            }
        }
    }
    
    console.log(`Total fields in batch: ${totalFields}`);
    console.log(`\nTo start documenting, open the first file and run:`);
    console.log(`  node scripts/auto-document-haxe.js status <file>`);
}

// Main
function main() {
    if (!command || command === 'help') {
        showHelp();
    } else if (command === 'next') {
        showNext();
    } else if (command === 'status' && filePath) {
        showStatus(filePath);
    } else if (command === 'verify' && filePath) {
        verifyFile(filePath);
    } else if (command === 'progress') {
        showProgress();
    } else if (command === 'batch') {
        createBatch(filePath);
    } else {
        console.error(`Unknown command: ${command}`);
        showHelp();
    }
}

main();