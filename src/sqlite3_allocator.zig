const c = @import("./c.zig").c;
const std = @import("std");
const assert = std.debug.assert;

// if initialized points to sqlite3_api_routines
// which is provided when the extention is loaded at runtime
// and since init is the only way to get an allocator,
// sqlite3_api is guaranteed to have a value
var sqlite3_api: ?*c.sqlite3_api_routines = null;

pub fn init(api: *c.sqlite3_api_routines) *Allocator {
    sqlite3_api = api;
    return &allocator_state;
}

const Allocator = std.mem.Allocator;

// Copied from raw_c_allocator.
// Asserts allocations are within `@alignOf(std.c.max_align_t)` and directly calls
// `malloc`/`free`. Does not attempt to utilize `malloc_usable_size`.
// This allocator is safe to use as the backing allocator with
// `ArenaAllocator` for example and is more optimal in such a case
// than `c_allocator`.

var allocator_state = Allocator{
    .allocFn = alloc,
    .resizeFn = resize,
};

fn alloc(
    self: *Allocator,
    len: usize,
    ptr_align: u29,
    len_align: u29,
    ret_addr: usize,
) Allocator.Error![]u8 {
    _ = self;
    _ = len_align;
    _ = ret_addr;
    assert(ptr_align <= @alignOf(std.c.max_align_t));
    // Panic if sqlite3_api is null
    // since it wouldn't make sense to check 
    // because we can't return any other error than OutOfMemory
    const ptr = @ptrCast([*]u8, sqlite3_api.?.*.malloc64.?(len) orelse return error.OutOfMemory);
    return ptr[0..len];
}

fn resize(
    self: *Allocator,
    buf: []u8,
    old_align: u29,
    new_len: usize,
    len_align: u29,
    ret_addr: usize,
) Allocator.Error!usize {
    _ = self;
    _ = old_align;
    _ = ret_addr;
    if (new_len == 0) {
    // Panic if sqlite3_api is null
    // since it wouldn't make sense to check 
    // because we can't return any other error than OutOfMemory
        sqlite3_api.?.*.free.?(buf.ptr);
        return 0;
    }
    if (new_len <= buf.len) {
        return std.mem.alignAllocLen(buf.len, new_len, len_align);
    }
    return error.OutOfMemory;
}
