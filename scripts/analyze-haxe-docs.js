#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

// Configuration
const RUNTIME_SRC = path.join(__dirname, '..', 'runtime', 'src');
const PLUGINS_DIR = path.join(__dirname, '..', 'plugins');
const TOOLS_SRC = path.join(__dirname, '..', 'tools', 'src');
const OUTPUT_FILE = path.join(__dirname, '..', 'HAXE_DOCS_DETAILED.md');

// Track all files and their documentation status
const allFiles = [];
let totalFields = 0;
let documentedFields = 0;
let totalPublicFields = 0;
let documentedPublicFields = 0;
let totalTypes = 0;
let documentedTypes = 0;

// Helper to check if a line starts a doc comment
function isDocCommentStart(line) {
    return line.trim().startsWith('/**');
}

// Helper to check if a line ends a doc comment
function isDocCommentEnd(line) {
    return line.trim().includes('*/');
}

// Helper to check if field is public
function isPublicField(line) {
    const trimmed = line.trim();
    // Check for public keyword or no access modifier (default is public in Haxe)
    if (trimmed.startsWith('public ')) return true;
    if (trimmed.startsWith('private ')) return false;
    if (trimmed.startsWith('inline public ')) return true;
    if (trimmed.startsWith('inline private ')) return false;
    if (trimmed.startsWith('static public ')) return true;
    if (trimmed.startsWith('static private ')) return false;
    if (trimmed.startsWith('override public ')) return true;
    if (trimmed.startsWith('override private ')) return false;
    
    // Check for function/var/final without explicit access modifier
    if (trimmed.startsWith('function ') || 
        trimmed.startsWith('var ') || 
        trimmed.startsWith('final ') ||
        trimmed.startsWith('static function ') ||
        trimmed.startsWith('static var ') ||
        trimmed.startsWith('inline function ') ||
        trimmed.startsWith('override function ')) {
        return true; // Default is public
    }
    
    return false;
}

// Extract field name from a line
function extractFieldName(line) {
    const trimmed = line.trim();
    
    // Remove access modifiers and other keywords
    let cleaned = trimmed
        .replace(/^(public|private|static|inline|override|final|dynamic|extern)\s+/g, '')
        .replace(/^(public|private|static|inline|override|final|dynamic|extern)\s+/g, ''); // May need multiple passes
    
    // Extract function name
    const funcMatch = cleaned.match(/^function\s+([a-zA-Z_][a-zA-Z0-9_]*)/);
    if (funcMatch) {
        const funcName = funcMatch[1];
        // Skip get_ and set_ methods as they don't need documentation
        // when the property itself is documented
        if (funcName.startsWith('get_') || funcName.startsWith('set_')) {
            return null;
        }
        return funcName;
    }
    
    // Extract variable/property name
    const varMatch = cleaned.match(/^(var|final)\s+([a-zA-Z_][a-zA-Z0-9_]*)/);
    if (varMatch) return varMatch[2];
    
    // Extract getter/setter
    const propMatch = cleaned.match(/^var\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\(/);
    if (propMatch) return propMatch[1];
    
    return null;
}

// Analyze a single Haxe file
function analyzeFile(filePath) {
    const content = fs.readFileSync(filePath, 'utf8');
    const lines = content.split('\n');
    
    const fileInfo = {
        path: filePath,
        relativePath: path.relative(path.join(__dirname, '..'), filePath),
        totalFields: 0,
        documentedFields: 0,
        publicFields: 0,
        documentedPublicFields: 0,
        fields: [],
        undocumentedPublicFields: [],
        types: [],
        undocumentedTypes: [],
        totalTypes: 0,
        documentedTypes: 0
    };
    
    let inDocComment = false;
    let hasDocComment = false;
    let inClass = false;
    let braceDepth = 0;
    let inMultilineString = false;
    
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        const trimmed = line.trim();
        
        // Skip empty lines
        if (!trimmed) continue;
        
        // Track multiline strings
        if (trimmed.includes("'''") || trimmed.includes('"""')) {
            inMultilineString = !inMultilineString;
        }
        if (inMultilineString) continue;
        
        // Skip single-line comments
        if (trimmed.startsWith('//')) continue;
        
        // Track doc comments
        if (isDocCommentStart(line)) {
            inDocComment = true;
            hasDocComment = true;
        }
        if (inDocComment && isDocCommentEnd(line)) {
            inDocComment = false;
            continue; // Don't process the closing */ line further
        }
        
        // Track class/interface/enum boundaries and their documentation
        const typeMatch = trimmed.match(/^(class|interface|abstract|enum|typedef)\s+([a-zA-Z_][a-zA-Z0-9_]*)/);
        if (typeMatch) {
            const typeKind = typeMatch[1];
            const typeName = typeMatch[2];
            
            // Record type documentation status
            const typeInfo = {
                kind: typeKind,
                name: typeName,
                line: i + 1,
                hasDoc: hasDocComment
            };
            
            fileInfo.types.push(typeInfo);
            fileInfo.totalTypes++;
            
            if (hasDocComment) {
                fileInfo.documentedTypes++;
                hasDocComment = false; // Reset after using for documented type
            } else {
                fileInfo.undocumentedTypes.push(typeInfo);
            }
            
            inClass = true;
            braceDepth = 0;
        }
        
        // Track brace depth
        for (const char of trimmed) {
            if (char === '{') braceDepth++;
            if (char === '}') {
                braceDepth--;
                if (braceDepth === 0) inClass = false;
            }
        }
        
        // Only analyze fields inside classes at the right depth
        if (!inClass || braceDepth !== 1) {
            // Don't reset hasDocComment here - it might be for an upcoming type declaration
            continue;
        }
        
        // Check if this line defines a field
        const isField = trimmed.match(/^(public|private|static|inline|override|final|function|var)\s+/) &&
                       !trimmed.startsWith('//') &&
                       !inDocComment;
        
        if (isField) {
            const fieldName = extractFieldName(line);
            const isPublic = isPublicField(line);
            
            if (fieldName && !fieldName.startsWith('_')) { // Skip internal fields starting with _
                const fieldInfo = {
                    name: fieldName,
                    line: i + 1,
                    isPublic: isPublic,
                    hasDoc: hasDocComment,
                    definition: trimmed.substring(0, Math.min(trimmed.length, 80))
                };
                
                fileInfo.fields.push(fieldInfo);
                fileInfo.totalFields++;
                if (hasDocComment) fileInfo.documentedFields++;
                if (isPublic) {
                    fileInfo.publicFields++;
                    if (hasDocComment) {
                        fileInfo.documentedPublicFields++;
                    } else {
                        fileInfo.undocumentedPublicFields.push(fieldInfo);
                    }
                }
            }
            
            hasDocComment = false;
        }
        
        // Reset doc comment flag if we hit a non-field line that's not empty
        // But preserve it through annotations (@:something, @something) and #if/#end directives
        if (!inDocComment && !isField && trimmed !== '' && 
            !trimmed.startsWith('@') && 
            !trimmed.startsWith('#if') && 
            !trimmed.startsWith('#elseif') && 
            !trimmed.startsWith('#else') && 
            !trimmed.startsWith('#end')) {
            hasDocComment = false;
        }
    }
    
    return fileInfo;
}

// Recursively find all .hx files
function findHaxeFiles(dir, files = []) {
    if (!fs.existsSync(dir)) return files;
    
    const items = fs.readdirSync(dir);
    for (const item of items) {
        const fullPath = path.join(dir, item);
        const stat = fs.statSync(fullPath);
        
        if (stat.isDirectory()) {
            // Skip certain directories
            if (item === 'node_modules' || item === '.git' || item === 'bin') continue;
            findHaxeFiles(fullPath, files);
        } else if (item.endsWith('.hx')) {
            files.push(fullPath);
        }
    }
    
    return files;
}

// Main analysis
function analyze() {
    console.log('Analyzing Haxe documentation at field level...\n');
    
    // Find all Haxe files
    const runtimeFiles = findHaxeFiles(RUNTIME_SRC);
    const pluginFiles = findHaxeFiles(PLUGINS_DIR);
    const toolFiles = findHaxeFiles(TOOLS_SRC);
    
    // Analyze each file
    const analyzeFiles = (files, category) => {
        console.log(`Analyzing ${files.length} files in ${category}...`);
        for (const file of files) {
            const info = analyzeFile(file);
            info.category = category;
            allFiles.push(info);
            
            totalFields += info.totalFields;
            documentedFields += info.documentedFields;
            totalPublicFields += info.publicFields;
            documentedPublicFields += info.documentedPublicFields;
            totalTypes += info.totalTypes;
            documentedTypes += info.documentedTypes;
        }
    };
    
    analyzeFiles(runtimeFiles, 'runtime');
    analyzeFiles(pluginFiles, 'plugins');
    analyzeFiles(toolFiles, 'tools');
    
    // Sort files by number of undocumented public fields (most first)
    allFiles.sort((a, b) => b.undocumentedPublicFields.length - a.undocumentedPublicFields.length);
    
    // Generate report
    generateReport();
}

// Generate markdown report
function generateReport() {
    let report = '# Haxe Documentation Analysis - Field Level\n\n';
    report += `Generated: ${new Date().toISOString()}\n\n`;
    
    // Overall statistics
    report += '## Overall Statistics\n\n';
    report += '### Types (Classes, Interfaces, Enums, etc.)\n';
    report += `- **Total Types**: ${totalTypes}\n`;
    report += `- **Documented Types**: ${documentedTypes} (${totalTypes > 0 ? ((documentedTypes/totalTypes)*100).toFixed(1) : 0}%)\n`;
    report += `- **Undocumented Types**: ${totalTypes - documentedTypes}\n\n`;
    report += '### Fields\n';
    report += `- **Total Fields**: ${totalFields}\n`;
    report += `- **Documented Fields**: ${documentedFields} (${totalFields > 0 ? ((documentedFields/totalFields)*100).toFixed(1) : 0}%)\n`;
    report += `- **Public Fields**: ${totalPublicFields}\n`;
    report += `- **Documented Public Fields**: ${documentedPublicFields} (${totalPublicFields > 0 ? ((documentedPublicFields/totalPublicFields)*100).toFixed(1) : 0}%)\n`;
    report += `- **Undocumented Public Fields**: ${totalPublicFields - documentedPublicFields}\n\n`;
    
    // Group by category
    const categories = ['runtime', 'plugins', 'tools'];
    
    // Files with undocumented types
    const filesWithUndocumentedTypes = allFiles.filter(f => f.undocumentedTypes.length > 0);
    report += `## Files with Undocumented Types (${filesWithUndocumentedTypes.length} files)\n\n`;
    
    for (const category of categories) {
        const categoryFiles = filesWithUndocumentedTypes.filter(f => f.category === category);
        if (categoryFiles.length === 0) continue;
        
        report += `### ${category.charAt(0).toUpperCase() + category.slice(1)} (${categoryFiles.length} files)\n\n`;
        
        for (const file of categoryFiles.slice(0, 20)) { // Limit to first 20 files
            report += `#### ${file.relativePath}\n`;
            report += `- Undocumented types:\n`;
            for (const type of file.undocumentedTypes) {
                report += `  - [ ] \`${type.kind} ${type.name}\` (line ${type.line})\n`;
            }
            report += '\n';
        }
    }
    
    // Files needing field documentation
    const filesNeedingDocs = allFiles.filter(f => f.undocumentedPublicFields.length > 0);
    report += `## Files Needing Field Documentation (${filesNeedingDocs.length} files)\n\n`;
    
    for (const category of categories) {
        const categoryFiles = filesNeedingDocs.filter(f => f.category === category);
        if (categoryFiles.length === 0) continue;
        
        report += `### ${category.charAt(0).toUpperCase() + category.slice(1)} (${categoryFiles.length} files)\n\n`;
        
        for (const file of categoryFiles) {
            const percent = file.publicFields > 0 
                ? ((file.documentedPublicFields / file.publicFields) * 100).toFixed(0)
                : '100';
            
            report += `#### ${file.relativePath}\n`;
            report += `- Public fields: ${file.documentedPublicFields}/${file.publicFields} documented (${percent}%)\n`;
            
            if (file.undocumentedPublicFields.length > 0) {
                report += `- Undocumented public fields:\n`;
                for (const field of file.undocumentedPublicFields) {
                    report += `  - [ ] \`${field.name}\` (line ${field.line}): ${field.definition}\n`;
                }
            }
            report += '\n';
        }
    }
    
    // Fully documented files
    const fullyDocumented = allFiles.filter(f => f.publicFields > 0 && f.undocumentedPublicFields.length === 0);
    report += `## Fully Documented Files (${fullyDocumented.length} files)\n\n`;
    
    for (const category of categories) {
        const categoryFiles = fullyDocumented.filter(f => f.category === category);
        if (categoryFiles.length === 0) continue;
        
        report += `### ${category.charAt(0).toUpperCase() + category.slice(1)}\n\n`;
        for (const file of categoryFiles) {
            report += `- [x] ${file.relativePath} (${file.publicFields} public fields)\n`;
        }
        report += '\n';
    }
    
    // Write report
    fs.writeFileSync(OUTPUT_FILE, report);
    console.log(`\nReport generated: ${OUTPUT_FILE}`);
    console.log(`\nSummary:`);
    console.log(`- Files with undocumented types: ${filesWithUndocumentedTypes.length}`);
    console.log(`- Total undocumented types: ${totalTypes - documentedTypes}`);
    console.log(`- Files needing field documentation: ${filesNeedingDocs.length}`);
    console.log(`- Fully documented files: ${fullyDocumented.length}`);
    console.log(`- Total undocumented public fields: ${totalPublicFields - documentedPublicFields}`);
}

// Run analysis
analyze();