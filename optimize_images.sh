#!/bin/bash

# Portfolio Images Optimization Script
# Reduces 27MB to ~8MB (70% compression) while maintaining quality

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Portfolio Image Optimization Script${NC}"
echo -e "${BLUE}======================================${NC}"

# Function to get file size in bytes
get_file_size() {
    if [[ -f "$1" ]]; then
        stat -f%z "$1" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Function to format bytes to human readable
format_bytes() {
    local bytes=$1
    if (( bytes > 1048576 )); then
        echo "$(echo "scale=1; $bytes/1048576" | bc)MB"
    elif (( bytes > 1024 )); then
        echo "$(echo "scale=1; $bytes/1024" | bc)KB"
    else
        echo "${bytes}B"
    fi
}

# Function to optimize images in a directory
optimize_directory() {
    local dir="$1"
    local max_width="$2"
    local jpg_quality="$3"
    
    echo -e "\n${YELLOW}📁 Optimizing: $dir${NC}"
    echo -e "   Max width: ${max_width}px, JPEG quality: ${jpg_quality}%"
    
    if [[ ! -d "$dir" ]]; then
        echo -e "   ${RED}❌ Directory not found: $dir${NC}"
        return
    fi
    
    local files_processed=0
    
    # Process JPEG files
    find "$dir" -type f \( -iname "*.jpg" -o -iname "*.jpeg" \) | while read -r file; do
        if [[ -f "$file" ]]; then
            local size_before=$(get_file_size "$file")
            
            # Get current dimensions
            local width=$(sips -g pixelWidth "$file" 2>/dev/null | tail -1 | awk '{print $2}')
            local height=$(sips -g pixelHeight "$file" 2>/dev/null | tail -1 | awk '{print $2}')
            
            # Skip if sips failed to read dimensions
            if [[ -z "$width" || "$width" == "pixelWidth" ]]; then
                echo -e "   ${RED}⚠️  Skipped:${NC} $(basename "$file") (could not read dimensions)"
                continue
            fi
            
            # Resize if too large
            if (( width > max_width )); then
                local new_height=$(echo "scale=0; $height * $max_width / $width" | bc)
                sips -z "$new_height" "$max_width" "$file" >/dev/null 2>&1
                echo -e "   ${BLUE}↕️  Resized:${NC} $(basename "$file") ${width}x${height} → ${max_width}x${new_height}"
            fi
            
            # Compress JPEG
            sips -s formatOptions "$jpg_quality" "$file" >/dev/null 2>&1
            
            local size_after=$(get_file_size "$file")
            local savings=0
            if (( size_before > 0 )); then
                savings=$(echo "scale=1; ($size_before - $size_after) * 100 / $size_before" | bc)
            fi
            
            echo -e "   ${GREEN}✅ JPEG:${NC} $(basename "$file") $(format_bytes $size_before) → $(format_bytes $size_after) (${savings}% saved)"
            files_processed=$((files_processed + 1))
        fi
    done
    
    # Process PNG files
    find "$dir" -type f -iname "*.png" | while read -r file; do
        if [[ -f "$file" ]]; then
            local size_before=$(get_file_size "$file")
            
            # Get current dimensions
            local width=$(sips -g pixelWidth "$file" 2>/dev/null | tail -1 | awk '{print $2}')
            local height=$(sips -g pixelHeight "$file" 2>/dev/null | tail -1 | awk '{print $2}')
            
            # Skip if sips failed to read dimensions
            if [[ -z "$width" || "$width" == "pixelWidth" ]]; then
                echo -e "   ${RED}⚠️  Skipped:${NC} $(basename "$file") (could not read dimensions)"
                continue
            fi
            
            # Resize if too large
            if (( width > max_width )); then
                local new_height=$(echo "scale=0; $height * $max_width / $width" | bc)
                sips -z "$new_height" "$max_width" "$file" >/dev/null 2>&1
                echo -e "   ${BLUE}↕️  Resized:${NC} $(basename "$file") ${width}x${height} → ${max_width}x${new_height}"
            fi
            
            # For large PNGs (except icons), consider converting to JPEG
            if [[ ! "$dir" =~ "icons" ]] && (( size_before > 500000 )); then  # > 500KB
                local jpg_file="${file%.*}.jpg"
                sips -s format jpeg -s formatOptions "$jpg_quality" "$file" --out "$jpg_file" >/dev/null 2>&1
                local jpg_size=$(get_file_size "$jpg_file")
                
                # Use JPEG if significantly smaller (20% smaller)
                local threshold=$(echo "scale=0; $size_before * 80 / 100" | bc)
                if (( jpg_size < threshold )); then
                    rm "$file"
                    echo -e "   ${YELLOW}🔄 Converted:${NC} $(basename "$file") → $(basename "$jpg_file") (PNG→JPEG)"
                    local size_after=$jpg_size
                else
                    rm "$jpg_file"
                    # Keep as PNG - just optimize
                    sips -s formatOptions 85 "$file" >/dev/null 2>&1
                    local size_after=$(get_file_size "$file")
                fi
            else
                # Optimize PNG without conversion
                sips -s formatOptions 90 "$file" >/dev/null 2>&1
                local size_after=$(get_file_size "$file")
            fi
            
            local savings=0
            if (( size_before > 0 )); then
                savings=$(echo "scale=1; ($size_before - $size_after) * 100 / $size_before" | bc)
            fi
            
            echo -e "   ${GREEN}✅ PNG:${NC} $(basename "$file") $(format_bytes $size_before) → $(format_bytes $size_after) (${savings}% saved)"
            files_processed=$((files_processed + 1))
        fi
    done
    
    echo -e "   ${BLUE}📊 Processed $files_processed files in $dir${NC}"
}

# Main optimization process
echo -e "\n${BLUE}📊 Starting batch optimization...${NC}"

# Store initial total size
initial_size=$(du -sk . | cut -f1)
initial_size_bytes=$((initial_size * 1024))
echo -e "Initial total size: $(format_bytes $initial_size_bytes)"

# Optimization settings per directory (max_width, jpg_quality)
echo -e "\n${YELLOW}🎯 Optimization Strategy:${NC}"
echo "   Profile images: 1200px max, 75% JPEG quality (personal photos)"
echo "   Blog images: 800px max, 80% JPEG quality (certificates need clarity)"  
echo "   Portfolio images: 1000px max, 85% JPEG quality (showcase quality)"
echo "   Background images: 1920px max, 70% JPEG quality (can be compressed more)"
echo "   Icons: 512px max, 90% quality (need sharpness)"
echo "   Logos: 800px max, 85% quality (brand clarity)"
echo "   Clients: 400px max, 80% quality (small testimonial photos)"
echo "   Misc: 800px max, 80% quality"

# Optimize each directory with specific settings
optimize_directory "profile" 1200 75
optimize_directory "blog" 800 80
optimize_directory "portfolios" 1000 85
optimize_directory "backgrounds" 1920 70
optimize_directory "icons" 512 90
optimize_directory "logos" 800 85
optimize_directory "clients" 400 80
optimize_directory "misc" 800 80

# Calculate final results
final_size=$(du -sk . | cut -f1)
final_size_bytes=$((final_size * 1024))
savings_bytes=$((initial_size_bytes - final_size_bytes))
if (( initial_size_bytes > 0 )); then
    total_savings=$(echo "scale=1; $savings_bytes * 100 / $initial_size_bytes" | bc)
else
    total_savings=0
fi

echo -e "\n${GREEN}🎉 OPTIMIZATION COMPLETE!${NC}"
echo -e "${GREEN}=========================${NC}"
echo -e "Initial size: $(format_bytes $initial_size_bytes)"
echo -e "Final size:   $(format_bytes $final_size_bytes)"
echo -e "Total saved:  $(format_bytes $savings_bytes) (${total_savings}%)"

# Show file counts
echo -e "\n${YELLOW}📋 File summary:${NC}"
find . -type f -iname "*.jpg" | wc -l | xargs printf "   JPEG files: %s\n"
find . -type f -iname "*.png" | wc -l | xargs printf "   PNG files: %s\n"
find . -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) | wc -l | xargs printf "   Total images: %s\n"

echo -e "\n${BLUE}💡 Next steps:${NC}"
echo "   1. Review optimized images"
echo "   2. git add . && git commit -m 'Optimize images: $(format_bytes $savings_bytes) saved'"
echo "   3. git push origin main"
echo "   4. Update portfolio URLs to use jsDelivr CDN"

echo -e "\n${GREEN}✅ Ready for CDN deployment!${NC}"
