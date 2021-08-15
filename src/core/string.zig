//! A variable length array of characters
//! We assume here that most strings will be kinda long
//! and that we will be adding and removing from them a lot
//! so there is no point in reallocating every time we make a modification

const std = @import("std");
const testing = std.testing;

/// String errors
pub const StringError = error {
    /// if we cannot reallocate to make this string bigger this is either b/c
    /// of operating system limits or we have reached the string len limit
    OutOfMemory,
    /// Attempting to insert or delete at an invalid index
    InvalidIndex,
};

/// The minimum size of a string
const MINSIZE = 16;

/// A variable length array of characters
pub const String = struct {

    /// Allocator for managing the buffer
    allocator: *std.mem.Allocator,

    /// contents of the string, and capacity
    buf: []u8,

    /// size of the buffer that the string takes up so far
    size: usize,

    /// length of the string in utf8 codepoints
    len: usize,

    const Self = @This();

    /// Creates an empty string
    pub fn init(allocator: *std.mem.Allocator) !Self {
        return Self{
            .allocator = allocator,
            .buf = allocator.alloc(u8, MINSIZE) catch |err| {
                return StringError.OutOfMemory;
            },
            .len = 0,
            .size = 0,
        };
    }

    /// Deletes a string
    pub fn deinit(self: Self) void {
        self.allocator.free(self.buf);
    }


    /// Insert a string literal at an offset in the string
    pub fn insert(self: *Self, at: usize, b: []const u8) !void {
        // assert that we can append at that point
        if (at > self.size)
            return StringError.InvalidIndex;

        // if we have room then we can move on to just inserting the new content
        // if not attempt to reallocate
        try self.insure(b.len);

        // first move the later part of the string
        memmove(
            self.buf[at..self.size],
            self.buf[at + b.len..],
        );
        // then move the contents of b into the buffer
        memmove(
            b[0..],
            self.buf[at..self.size+b.len],
        );

        // add to length and size
        self.size += b.len;
        // TODO: make this in utf8!
        self.len += b.len;
    }

    /// Deletes a string literal at an offset in the string
    pub fn delete(self: *Self, at: usize, data: []const u8) !void {

    }

    // helper functions
    /// insure that the string can accomodate an addition of n bytes
    fn insure(self: *Self, n: usize) !void {
        if (self.size + n >= self.buf.len) {
            // allocate the length needed plus 100
            // TODO: clamp new size
            const new_size = self.size + n + 100;
            self.buf = self.allocator.realloc(self.buf, new_size) catch |err| {
                return StringError.OutOfMemory;
            };
        }
    }
};

/// moves bytes from one location to another
pub fn memmove(src: []const u8, dest: []u8) void {
    const n = src.len;
    // if the source is greater than the destination then go forwards
    // otherwise go backwards
    if (@ptrToInt(dest.ptr) < @ptrToInt(src.ptr)) {
        var index: usize = 0;
        while (index != n) : (index += 1) {
            dest[index] = src[index];
        }
    } else {
        var index = n;
        while (index != 0) {
            index -= 1;
            dest[index] = src[index];
        }
    }
}

test "init" {
    var str = try String.init(testing.allocator);
    defer str.deinit();
    try testing.expect(str.len == 0);
    try testing.expect(str.size == 0);
    try testing.expect(str.buf.len == MINSIZE);
}

test "add normal string literal" {
    var str = try String.init(testing.allocator);
    defer str.deinit();
    try testing.expect(str.len == 0);
    try testing.expect(str.size == 0);
    try testing.expect(str.buf.len == MINSIZE);

    //// add string literal of ascii characters
    try str.insert(0, "asdf");
    // len is 4 b/c 4 characters added
    // size is also 4 because each is one byte
    try testing.expect(str.len == 4);
    try testing.expect(str.size == 4);
    // len is 16 because we have not needed to reallocate yet
    try testing.expect(str.buf.len == 16);
    // expect the contents to be the same as the inserted string
    try testing.expect(std.mem.eql(u8, str.buf[0..str.size], "asdf"));

    // now lets add in the middle of the string
    try str.insert(2, "hjkl");
    try testing.expect(str.len == 8);
    try testing.expect(str.size == 8);
    try testing.expect(str.buf.len == MINSIZE);
    try testing.expect(std.mem.eql(u8, str.buf[0..str.size], "ashjkldf"));

    // and do an add that makes it grow the buffer
    // should trigger resize becase we have reached the minsize
    try str.insert(str.size, "01234567");
    try testing.expect(str.len == 16);
    try testing.expect(str.size == 16);
    try testing.expect(str.buf.len == 116);
    try testing.expect(std.mem.eql(u8, str.buf[0..str.size], "ashjkldf01234567"));
}