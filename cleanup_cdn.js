#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

console.log('🔍 Analyzing CDN image usage in portfolio project...\n');

// Get all images in CDN repository
const getAllCdnImages = () => {
  try {
    const result = execSync('find . -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.svg" -o -iname "*.webp" \\) | grep -v "/.git/" | sed "s|^\\./||"', { encoding: 'utf-8' });
    return result.trim().split('\n').filter(line => line.trim());
  } catch (error) {
    console.error('Error getting CDN image files:', error.message);
    return [];
  }
};

// Find image references in portfolio project
const findUsedImages = () => {
  const usedImages = new Set();
  const projectPath = '../Portofolio-NodeJS';
  
  try {
    // Get all CDN references from the portfolio project
    const cdnRefs = execSync(`cd "${projectPath}" && grep -r "portfolio-images-temp" . --include="*.ejs" --include="*.css" --include="*.js" || true`, { encoding: 'utf-8' });
    
    // Extract image paths from CDN URLs
    const lines = cdnRefs.split('\n');
    lines.forEach(line => {
      // Match CDN URLs and extract the path after /main/
      const matches = line.match(/portfolio-images-temp\/main\/([^"'\s)]+\.(jpg|jpeg|png|gif|svg|webp))/gi);
      if (matches) {
        matches.forEach(match => {
          const imagePath = match.replace(/.*\/main\//, '');
          usedImages.add(imagePath);
        });
      }
    });

    // Also check for any direct filename references
    const allCdnImages = getAllCdnImages();
    allCdnImages.forEach(imgPath => {
      const filename = path.basename(imgPath);
      try {
        const filenameRefs = execSync(`cd "${projectPath}" && grep -r "${filename}" . --include="*.ejs" --include="*.css" --include="*.js" || true`, { encoding: 'utf-8' });
        if (filenameRefs.trim()) {
          usedImages.add(imgPath);
        }
      } catch (e) {
        // Continue if grep fails
      }
    });

  } catch (error) {
    console.error('Error searching for CDN references:', error.message);
  }
  
  return Array.from(usedImages);
};

// Get file size in human-readable format
const getFileSize = (filePath) => {
  try {
    const stats = fs.statSync(filePath);
    const bytes = stats.size;
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
  } catch (error) {
    return 'Unknown';
  }
};

// Main analysis
const allCdnImages = getAllCdnImages();
const usedImages = findUsedImages();

console.log(`📊 Total CDN images: ${allCdnImages.length}`);
console.log(`📎 Used CDN images: ${usedImages.length}\n`);

// Find unused images in CDN
const unusedCdnImages = [];
let totalUnusedSize = 0;

allCdnImages.forEach(imgPath => {
  const isUsed = usedImages.some(usedImg => 
    usedImg === imgPath || 
    usedImg.includes(imgPath) ||
    imgPath.includes(usedImg) ||
    path.basename(usedImg) === path.basename(imgPath)
  );
  
  if (!isUsed) {
    try {
      const size = fs.statSync(imgPath).size;
      totalUnusedSize += size;
      unusedCdnImages.push({
        path: imgPath,
        size: getFileSize(imgPath),
        bytes: size
      });
    } catch (error) {
      console.error(`Error reading ${imgPath}:`, error.message);
    }
  }
});

// Display results
console.log('✅ USED CDN IMAGES:');
console.log('===================');
usedImages.sort().forEach(img => console.log(`  ${img}`));

console.log('\n❌ UNUSED CDN IMAGES:');
console.log('=====================');
if (unusedCdnImages.length === 0) {
  console.log('  🎉 No unused CDN images found!');
} else {
  unusedCdnImages.sort((a, b) => b.bytes - a.bytes).forEach(img => {
    console.log(`  ${img.path} (${img.size})`);
  });
  
  const totalSize = totalUnusedSize / (1024 * 1024);
  console.log(`\n💾 Total unused CDN space: ${totalSize.toFixed(2)} MB`);
  
  // Generate delete commands
  console.log('\n🗑️  CDN DELETE COMMANDS:');
  console.log('========================');
  unusedCdnImages.forEach(img => {
    console.log(`rm "${img.path}"`);
  });
}

console.log(`\n📈 Summary: ${unusedCdnImages.length} unused CDN images out of ${allCdnImages.length} total`);
