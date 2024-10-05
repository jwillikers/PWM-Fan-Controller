#!/usr/bin/env nu
use check-image-metadata.nu contains_geolocation_metadata

use std assert

def test_contains_geolocation_metadata [] {
    for t in [
        [input expected];
        ['
Image:
  Filename: /home/jdoe/Pictures/picture.jpg
  Permissions: rw-r--r--
  Format: JPEG (Joint Photographic Experts Group JFIF format)
  Mime type: image/jpeg
  Class: DirectClass
  Geometry: 4032x3024+0+0
  Units: Undefined
  Colorspace: sRGB
  Type: TrueColor
  Base type: Undefined
  Endianness: Undefined
  Depth: 8-bit
  Channels: 3.0
  Channel depth:
    Red: 8-bit
    Green: 8-bit
    Blue: 8-bit
  Channel statistics:
    Pixels: 12192768
    Red:
      min: 0  (0)
      max: 255 (1)
      mean: 133.213 (0.522404)
      median: 140 (0.54902)
      standard deviation: 31.6085 (0.123955)
      kurtosis: 6.25607
      skewness: -2.37688
      entropy: 0.788975
    Green:
      min: 0  (0)
      max: 255 (1)
      mean: 125.504 (0.492172)
      median: 130 (0.509804)
      standard deviation: 32.9402 (0.129177)
      kurtosis: 3.19772
      skewness: -1.42089
      entropy: 0.840793
    Blue:
      min: 0  (0)
      max: 255 (1)
      mean: 114.747 (0.449989)
      median: 114 (0.447059)
      standard deviation: 37.7443 (0.148017)
      kurtosis: 1.33805
      skewness: 0.112212
      entropy: 0.895613
  Image statistics:
    Overall:
      min: 0  (0)
      max: 255 (1)
      mean: 124.488 (0.488188)
      median: 128 (0.501961)
      standard deviation: 34.0977 (0.133716)
      kurtosis: 3.59728
      skewness: -1.22852
      entropy: 0.841794
  Rendering intent: Perceptual
  Gamma: 0.454545
  Chromaticity:
    red primary: (0.64,0.33,0.03)
    green primary: (0.3,0.6,0.1)
    blue primary: (0.15,0.06,0.79)
    white point: (0.3127,0.329,0.3583)
  Matte color: grey74
  Background color: white
  Border color: srgb(223,223,223)
  Transparent color: black
  Interlace: None
  Intensity: Undefined
  Compose: Over
  Page geometry: 4032x3024+0+0
  Dispose: Undefined
  Iterations: 0
  Compression: JPEG
  Quality: 100
  Orientation: TopLeft
  Profiles:
    Profile-exif: 754 bytes
    Profile-icc: 596 bytes
  Properties:
    exif:DateTime: 2019:10:04 14:21:48
    exif:DateTimeDigitized: 2019:10:04 14:21:48
    exif:DateTimeOriginal: 2019:10:04 14:21:48
    exif:ExifOffset: 146
    exif:ExifVersion: 0220
    exif:ExposureTime: 16661248/1000000000
    exif:Flash: 0
    exif:FNumber: 18900/10000
    exif:FocalLength: 54300/10000
    exif:GPSAltitude: 4400000/10000
    exif:GPSAltitudeRef: .
    exif:GPSDateStamp: 2019:10:04
    exif:GPSInfo: 473
    exif:GPSLatitude: 77/1,50/1,477240000/10000000
    exif:GPSLatitudeRef: N
    exif:GPSLongitude: 113/1,31/1,148080000/10000000
    exif:GPSLongitudeRef: E
    exif:GPSProcessingMethod: gps
    exif:GPSSpeed: 1/10000
    exif:GPSSpeedRef: K
    exif:GPSTimeStamp: 10/1,10/1,53/1
    exif:ImageLength: 3024
    exif:ImageWidth: 4032
    exif:LightSource: 0
    exif:Make: Google
    exif:Model: Pixel 7a
    exif:OffsetTime: -5:00
    exif:OffsetTimeDigitized: -05:00
    exif:OffsetTimeOriginal: -5:00
    exif:PhotographicSensitivity: 92
    exif:PixelXDimension: 4032
    exif:PixelYDimension: 3024
    exif:SubSecTime: 715440
    exif:SubSecTimeDigitized: 715440
    exif:SubSecTimeOriginal: 715440
    exif:WhiteBalance: 0
    icc:copyright: Copyright (c) 2016 Google Inc.
    icc:description: sRGB IEC61966-2.1
    jpeg:colorspace: 2
    jpeg:sampling-factor: 2x2,1x1,1x1
    signature: e2da0048c346c64b1027570a52ed107a7e2d8ba8948bdc3e1abb732eae876936
  Artifacts:
    verbose: true
  Tainted: False
  Filesize: 5.61776MiB
  Number pixels: 12.1928M
  Pixel cache type: Memory
  Pixels per second: 64.6839MP
  User time: 0.190u
  Elapsed time: 0:01.188
  Version: ImageMagick 7.1.1-38 Q16-HDRI x86_64 878daf986:20240901 https://imagemagick.org
        ' true]
        ['
Image:
  Filename: qt-py-ch32v203-pwm-fan-controller-breadboard-side-1.jpg
  Permissions: rw-r--r--
  Format: JPEG (Joint Photographic Experts Group JFIF format)
  Mime type: image/jpeg
  Class: DirectClass
  Geometry: 3749x1899+0+0
  Resolution: 72x72
  Print size: 52.0694x26.375
  Units: PixelsPerInch
  Colorspace: sRGB
  Type: TrueColor
  Base type: Undefined
  Endianness: Undefined
  Depth: 8-bit
  Channels: 3.0
  Channel depth:
    Red: 8-bit
    Green: 8-bit
    Blue: 8-bit
  Channel statistics:
    Pixels: 7119351
    Red:
      min: 0  (0)
      max: 255 (1)
      mean: 149.173 (0.584994)
      median: 162 (0.635294)
      standard deviation: 42.0394 (0.16486)
      kurtosis: 1.97136
      skewness: -1.53147
      entropy: 0.87033
    Green:
      min: 0  (0)
      max: 255 (1)
      mean: 148.68 (0.583058)
      median: 162 (0.635294)
      standard deviation: 46.0756 (0.180689)
      kurtosis: 0.653392
      skewness: -0.94745
      entropy: 0.907808
    Blue:
      min: 0  (0)
      max: 255 (1)
      mean: 147.479 (0.578349)
      median: 152 (0.596078)
      standard deviation: 60.0636 (0.235543)
      kurtosis: -0.834978
      skewness: -0.32204
      entropy: 0.971006
  Image statistics:
    Overall:
      min: 0  (0)
      max: 255 (1)
      mean: 148.444 (0.582133)
      median: 158.667 (0.622222)
      standard deviation: 49.3928 (0.193697)
      kurtosis: 0.596592
      skewness: -0.933654
      entropy: 0.916381
  Rendering intent: Perceptual
  Gamma: 0.454545
  Chromaticity:
    red primary: (0.64,0.33,0.03)
    green primary: (0.3,0.6,0.1)
    blue primary: (0.15,0.06,0.79)
    white point: (0.3127,0.329,0.3583)
  Matte color: grey74
  Background color: white
  Border color: srgb(223,223,223)
  Transparent color: black
  Interlace: None
  Intensity: Undefined
  Compose: Over
  Page geometry: 3749x1899+0+0
  Dispose: Undefined
  Iterations: 0
  Compression: JPEG
  Quality: 100
  Orientation: Undefined
  Properties:
    jpeg:colorspace: 2
    jpeg:sampling-factor: 2x2,1x1,1x1
    signature: 8bf704578aa37fbb3c2425a55ad0c989779a584551aa603286a4504f23ecccad
  Artifacts:
    verbose: true
  Tainted: False
  Filesize: 3.27405MiB
  Number pixels: 7.11935M
  Pixel cache type: Memory
  Pixels per second: 65.2504MP
  User time: 0.110u
  Elapsed time: 0:01.109
  Version: ImageMagick 7.1.1-38 Q16-HDRI x86_64 878daf986:20240901 https://imagemagick.org
        ' false]
    ] {
        assert equal ($t.input | contains_geolocation_metadata) $t.expected
    }
}

def main [] [] {
    test_contains_geolocation_metadata
    echo "All tests passed!"
}
