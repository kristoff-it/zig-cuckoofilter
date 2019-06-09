#import <stdio.h>
#import "cuckoofilter_c.h"

//
// Compile using:
//
// GCC:
// $ gcc -o c_example c_example.c path/to/cuckoofilter_c.o
//
// Zig:
// $ zig build-exe --c-source c_example.c --library c --object path/to/cuckoofilter_c.o
//
// You can obtain cuckoofilter_c.o either by downloading it from the latest Release on GitHub
// or by compiling the library using the Zig compiler:
// 
// $ zig build-obj --release-fast src/cuckoofilter_c.zig
//

int main(int argc, char const *argv[])
{
	int err;
	int found;

	unsigned char memory[1024];
	struct Filter8 cf;

	err = cf_init8(memory, 1024, &cf);
	if (err != 0) {
		printf("Error!\n");
	}	

	// Search for the item hash = 0, fp = 'a'
	err = cf_maybe_contains8(&cf, 0, 'a', &found);
	if (err != 0) {
		printf("Error!\n");
	}
	printf("%d\n", found);

	// Add the item
	err = cf_add8(&cf, 0, 'a');
	if (err != 0) {
		printf("Error!\n");
	}

	// Search it again
	err = cf_maybe_contains8(&cf, 0, 'a', &found);
	if (err != 0) {
		printf("Error!\n");
	}
	printf("%d\n", found);

	return 0;
}