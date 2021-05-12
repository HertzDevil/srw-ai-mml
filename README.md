# srw-ai-mml

Collection of Lua scripts for editing music from Super Robot Wars A / R / D / J

## putsongs.lua

Inserts MML into the given ROM. Requires a song list, which has the following format:

```
FB2000
04      music/custom/invoke.mml
25      music/custom/moon_knights.mml
```

The first line contains the hex address where the music is to be inserted. All songs are inserted contiguously at that address, so make sure you have enough space and expand the ROM if necessary.

After that, each line must start with a hex number representing the target song ID in the ROM, followed by some whitespace, and then the MML file name relative to the current working directory. `;` can be used for comments in the song list.

Refer to `mml-format.txt` (very rudimentary) and the custom MML files for the MML commands supported.

## putsamples.lua

Inserts instrument samples into the given ROM. Requires a sample list, which has the same format as song lists (except files should be `.bin`).

Each sample file consists of a 16-bit little-endian sample rate, followed by 8-bit signed sample values. The sample size is automatically handled by this script.

## getsongs.lua

Decompiles all music from the given ROM, then prints a song list to the standard output. Normally you shouldn't have to use this script at all.

## getsamples.lua

Extracts all (instrument) samples from the given ROM, then prints a sample list to the standard output. Again you shouldn't have to use this script, but there is commented out code that emits the samples as WAV files.

## Usage

`music/custom/list_*.txt` and `sample/custom/list_*.txt` are used to insert my own custom songs into the respective ROMs. For example, to apply the songs to SRW J:

```
$ lua putsongs.lua srwj.gba music/custom/list_j.txt
$ lua putsamples.lua srwj.gba sample/custom/list_j.txt
```

The song lists for A / R / D assume a ROM size of 16 MB.

All original songs and samples are also available. The following re-inserts all original songs in SRW J:

```
$ lua putsongs.lua srwj.gba music/j/list.txt
$ lua putsamples.lua srwj.gba sample/j/list.txt
```

All 4 supported games are verified to produce identical ROMs when re-inserted this way.

## Licensing

The scripts are licensed under the MIT License.
