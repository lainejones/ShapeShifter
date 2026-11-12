/* shapeshifter.ld - reproduce the hunk layout of the PhxLnk-built 3.11 binary:
 *   startup + catalog strings, startup data, main code, data, chip data,
 *   bss, chip bss, Boopsi getfile class.
 * Output sections named .datachip / .bsschip are written as MEMF_CHIP hunks. */
SECTIONS
{
  .text      : { *(startup) *(.text) }
  .code      : { *(CODE) }
  .data      : { *(DATA) }
  .datachip  : { *(CHIPDATA) }
  .bss       : { *(startupbss) *(BSS) }
  .bsschip   : { *(CHIPBSS) }
  .getfile   : { *(getfile) }
}
