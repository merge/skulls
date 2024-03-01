In order to create your own splashscreen image, before building,
overwrite the `bootsplash.jpg` with your own JPEG, using
* "Progressive" turned off, and
* "4:2:0 (chroma quartered)" Subsampling

You can use `imagemagick` to prepare the .jpg file using:
* `mogrify logo.jpg -interlace none <splashscreen>`
* `mogrify logo.jpg -sampling-factor 4:2:0 <splashscreen>`
* `convert <splashscreen> -resize 1024x768! <splashscreen> # optional, but converts image size to match screen dimensions`

`ImageMagick` can also be used to convert images of another format into .jpg using the [convert](https://imagemagick.org/script/convert.php) tool.

**Note**: replace `<splashscreen>` with the file name.
