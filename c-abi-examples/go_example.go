package main

// TODO: update lines 12 and 13 with the path where libcuckoofilter_c.{dynlib, so, dll} is stored.
//      eg (when the file is saved in the repo's root directory (i.e. one level above where this file lives)):
//          #cgo CFLAGS: -I ../
//          #cgo LDFLAGS: -L ../ -lcuckoofilter_c.0.0.0
//

// On macOS dynamic libraries have the .dylib extension. Windows has .dll and linux has .so
// You can obtain libcuckoofilter_c.xxx.{dynlib, so, dll} either by downloading it from the 
// latest Release on GitHub or by compiling the library using the Zig compiler:
// 
// $ zig build-lib -dynamic --release-fast src/cuckoofilter_c.zig
//
// On macOS this currently produces a dylib file that ld doesn't like so I had to use gcc 
// as follows:
//
// $ zig build-obj --release-fast  src/cuckoofilter_c.zig
// $ gcc -dynamiclib -o libcuckoofilter_c.0.0.0.dylib cuckoofilter_c.o
//

/*
#cgo CFLAGS: -I ../
#cgo LDFLAGS: -L ../ -l cuckoofilter_c.0.0.0
#include <stdint.h>
#include "cuckoofilter_c.h"
*/
import "C"
import (
    "fmt"
)

func main() {
	var err C.int
    var found C.int

    // Allocate the memory
    cf8 := C.struct_Filter8{}
    memory := make([]C.uint8_t, 1024)

    // Initialize the filter
    err = C.cf_init8(&memory[0], 1024, &cf8)
    if err != 0 {
    	fmt.Println("Error!")
    }

    // Add a fingerprint
    err = C.cf_add8(&cf8, 0, 'a')
	if err != 0 {
    	fmt.Println("Error!")
    }

    // Search for it
    err = C.cf_maybe_contains8(&cf8, 0, 'a', &found)
    if err != 0 {
    	fmt.Println("Error!")
    }
    fmt.Printf("Found? %d\n", found)

    // Search non-existing item
    err = C.cf_maybe_contains8(&cf8, 0, 'b', &found)
    if err != 0 {
    	fmt.Println("Error!")
    }
    fmt.Printf("Found? %d\n", found)
}