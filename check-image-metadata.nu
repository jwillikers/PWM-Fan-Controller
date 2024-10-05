#!/usr/bin/env nu
use std log

# Some common image file extensions.
const image_file_extensions = [
    gif
    jpg
    jpeg
    png
    webp
]

# Determine if the given file is an image.
def is-image [] [path -> bool] {
    ^file --brief --mime-type $in | str starts-with "image/"
}

# A wrapper around the magick identify command.
def "magick identify" [] [path -> string] {
    let file = $in
    let result = (^magick identify -verbose $file | complete)
    if $result.exit_code != 0 {
        log warning $"The 'magick identify -verbose' command failed on the image file '($file)' with exit code ($result.exit_code): ($result.stderr)"
        return null
    }
    return $result.stdout
}

# Check if the output from the 'magick identify -verbose' command contains geolocation metadata with ImageMagick.
export def contains_geolocation_metadata [] [string -> bool] {
    $in | str contains "exif:GPS"
}

# Find if any image files which contain geolocation metadata and report an error if any do.
#
# When given no files, it checks all files that use common image file extensions.
def main [
    ...files: path
    --strip
] {
    let images = (
        if ($files | is-empty) {
            $image_file_extensions | par-each {|image_file_extension|
                glob $"**/*.($image_file_extension)"
            } | flatten
        } else {
            $files | filter {|file| $file | is-image}
        }
    )
    log debug $"images: ($images)"

    let images_with_geolocation_metdata = (
        $images | filter {|image| $image | magick identify | contains_geolocation_metadata}
    )

    if ($images_with_geolocation_metdata | is-empty) {
        exit 0
    }

    (
        $images_with_geolocation_metdata | par-each {
            let image = $in
            if $strip {
                ^mogrify -strip $image
                log info $"Stripped metadata from the image '($image)'."
            } else {
                log error $"Image '($image)' contains geolocation metadata."
            }
        }
    )

    if $strip {
        exit 0
    }

    exit 1
}
