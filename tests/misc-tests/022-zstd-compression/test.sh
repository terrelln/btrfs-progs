#!/bin/bash
# Test zstd compression support on a prebuilt btrfs image

source "$TOP/tests/common"

check_prereq btrfs

# Extract the test image
image=$(extract_image compress.raw.xz)

check_dump_tree() {
	local image=$1
	local string=$2
	"$TOP/btrfs" inspect-internal dump-tree "$image" \
		| grep "$string" > /dev/null \
		|| _fail "btrfs inspect-internal dump-tree didn't print $string"
}
# Check that there are blocks of each compression type
check_dump_tree "$image" "extent compression 1 (zlib)"
check_dump_tree "$image" "extent compression 2 (lzo)"
check_dump_tree "$image" "extent compression 3 (zstd)"

# Check that the filesystem has incompat COMPRESS_ZSTD
"$TOP/btrfs" inspect-internal dump-super -f "$image" \
	| grep COMPRESS_ZSTD > /dev/null \
	|| _fail "btrfs inspect-internal dump-super no incompat COMPRESS_ZSTD"

# Create a temporary directory and restore the filesystem
restore_tmp=$(mktemp --tmpdir -d btrfs-progs-022-zstd-compression.XXXXXXXXXX)
run_check "$TOP/btrfs" restore "$image" "$restore_tmp"

# Expect 3 files
num_files=$(ls -1 "$restore_tmp" | wc -l)
[ "$num_files" == 3 ] || _fail "number of files does not match"

check_md5() {
	local file="$1"
	local expect_md5="$2"
	md5=$(run_check_stdout md5sum "$file" | cut -d ' ' -f 1)
	[ "$md5" == "$expect_md5" ] \
		|| _fail "$file digest $md5 does not match $expect_md5"
}
# Each should be 200K of zeros
expect_md5=$(run_check_stdout head -c 200K /dev/zero | md5sum | cut -d ' ' -f 1)
check_md5 "$restore_tmp/zlib" "$expect_md5"
check_md5 "$restore_tmp/lzo" "$expect_md5"
check_md5 "$restore_tmp/zstd" "$expect_md5"

# Clean up
rm -r -- "$restore_tmp"
rm -- "$image"
