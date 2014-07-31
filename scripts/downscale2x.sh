#!/bin/bash

# This script takes images in the form of image_name@2x.png creates image_name.png and optimizes both.

if [ ! `which convert` ]; then
    echo "sorry, imagemagick is not installed."
    exit 1
fi

wd=`pwd`

tmpdir=`mktemp -d -t downscale2x` || exit 1
#echo "working in temp dir $tmpdir"
file_prefixes=`ls *@2x.png | cut -d '@' -f 1`

echo "Downscaling @2x.png images..."
for fp in $file_prefixes; do
    orig="$fp@2x.png"
    small="$fp.png"
    
    cmd="cp $orig $tmpdir"
    eval $cmd || echo "$cmd failed: $!"
    
    if [ ! -f $small ]; then
      cmd="convert $tmpdir/$orig -resize 50% $tmpdir/$small"
    else
      cmd="cp $small $tmpdir"
    fi 
    eval $cmd || echo "$cmd failed: $!"

done

# echo "converted files are in $tmpdir"
# ls -l $tmpdir

echo "Optimizing PNGs..."
if [ `which pngcrush` ]; then
    compressed_dir=`mktemp -d -t downscale2x`
    cmd="pngcrush -q -brute -d $compressed_dir $tmpdir/*.png"
    eval $cmd || echo "$cmd failed: $!"
    #echo "compressed files are in $compressed_dir"
    cmd="[ $tmpdir ] && rm -rf $tmpdir"
    eval $cmd || echo "$cmd failed"
else
    echo "pngcrush not found... consider installing it for smaller output"
    compressed_dir=$tmpdir
fi

echo "Cleaning up..."

cmd="cp $compressed_dir/*.png $wd"
eval $cmd || echo "$cmd failed"

cmd="[ $compressed_dir ] && rm -rf $compressed_dir"
eval $cmd || echo "$cmd failed"

echo "done."