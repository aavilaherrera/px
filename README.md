# px

A collection of bash functions for ingesting pictures (and video)

## Usage

```
# rename and organize media in INGEST_DIR into year-month sub-directories, and
# and finally move them into DESTINATION_DIR

px auto INGEST_DIR DESTINATION_DIR

# help

px: a toolset for moving pictures around

usage: px <command> [options] <args>

commands:
    date2filename
    by-year-month
    move
    list-dates
    untag-faces
    tag-faces
    auto
    commands
    help

```

## Install

1. Install dependencies by hand

   - bash >= 4
   - exiftool
   - GNU parallel
   - https://github.com/ageitgey/face_recognition (optional)

2. `make install`

   Read the `Makefile` to see where things are installed...

## Intended workflow

The goal is for `px` to automate the following workflow:

1. Rename media files *and* their sidecars from datetime metadata
2. Group files *and* sidecars into subfolders by date
3. Apply tags, perform facial recognition, curate, etc...
4. Move media to destination film roll folder

## Background

### Video and AAE

While darktable and DigiKam have powerful DAM capabilities, darktable does not
handle video files or `.AAE` sidecars as it is primarily a raw image developer.
DigiKam does handle video and properly named `.AAE` sidecars (But sometimes
iPhones create an extra `.AAE` sidecar that breaks DigiKam's expected naming
scheme e.g., `BASENAME 1.AAE`).

### Face/people tagging

Darktable does not have built-in face recognition support. Its *contrib*
`face_recognition` script does tag whole images without adding face regions,
however, it requires extra manual setup.

- `ageitgey/face_recognition` in path
- a folder of known faces (`KNOWN_FACES`)
  - images of known faces must be named with the name of the tag (including
    hierarchical tags), and must not end in a number
  - an optional numbered suffix is allowed for multiple images of the same face
    (e.g., `People|George Costanza1.jpg`)

DigiKam has face recognition built in, with a pretty good
detect-recognize-review interface. But it feels slow to me, has unintuitive
buttons, and it is easy to make mistakes as the thumbnails jump around as
they are processed.

Unfortunately, I also find DigiKam's batch queue interface unintuitive and
cumbersome. DigiKam does not appear as reliable or performant as darktable
(constant database maintenance, constant need to sync metadata, file overwrite
on move problems, unwieldy search, etc...).

`px` has a few extras that don't exactly help, yet...:

- `px digikam-extract-faces`: extracts faces from Digikam's database to `.jpg`s
  in a "known faces" folder. (requires setting some environment variables, see
  `px_digikam-extract-faces.bash`)
- px `refine-known-faces`: detects faces in `KNOWN_FACES` to remove bad crops
  and face regions

## Known problems and to-dos

- `px digikam-extract-faces` outputs thumbnails to subdirectories, one per tag,
  with images numbered by the order dumped from the DigiKam database (e.g.,
  George Costanza/23.jpg)
- `px digikam-extract-faces` might not handle images in certain orientations or
  after a rotation, resulting in bad crops, these can be removed with `px
  refine-known-faces`, but ideally, they would be extracted correctly in the
  first place.
- **TODO**: write a *contrib* script based on `face_recognition` that supports:
  - a friendlier `KNOWN_FACES` hierarchy?
  - loading saved face models/embeddings instead of processing images in `KNOWN_FACES`
    each time.
- **TODO**: support clustering or some other ML to *speed up* face tagging in
  `px`
  - number of faces is (much?) less than the number of thumbnails/face regions
  - comparing each new face against "average" faces instead of every known face
    regions may help with faces that look different in various situations
    (looking away, glasses, facial hair, aging)
  - `opencv` is supposed to be able to recognize and label faces in live
    streaming video, whereas the out-of-the-box `ageitgey/face_recognition` scripts take
    2-5 seconds per image.
- **TODO**: rewrite as python/perl/lua script?
  - pros: may be easier to do CLI, logging, functions/variables, OOP in python
  - cons: adds another dependency, time to rewrite, figure out how to replace `find | parallel` pattern
  - python: can import `face_recognition` library
  - perl: can use `Image::ExifTool` perl library directly
  - lua: can potentially re-write as a darktable plugin directly
