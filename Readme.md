# LLRBTree for Zig: Set and Map container

This library provides kinds of container data structures: set of values and key/value map.
These containers are implemented with the Left Leaning Red-Black trees that is a BST (Balanced Binary Tree) algorithm.


## Overview of Set of values

Basic operations on the `LLRBTreeSet` of `u32` is presented in the following:

```zig
var set = rbtree.llrbset.LLRBTreeSet(u32).new(alloc, .{});
defer set.destroy();
// For adding a value, use `insert` function.
// The old value would be returned from the function if exists already.
_ = try set.insert(5);
// the old value 5 is returned
assert((try set.insert(5)).? == 5);
assert((try set.insert(7)) == null);

// To lookup a value from a set, use `get` function.
// `null` is returned if it is not exists in the set.
assert(set.get(&@as(u32, 5)).?.* == 5);
assert(set.get(&@as(u32, 10)) == null);

// To delete a value, use `delete` function.
// The deleted value is returned from the function.
assert(set.delete(&@as(u32, 5)).? == 5);
// '3' have been deleted already
assert(set.delete(&@as(u32, 5)) == null);

_ = try set.insert(5);
_ = try set.insert(9);
// iterators enumerate values in ascending order
var items = set.iter();
assert(items.next().?.* == 5);
assert(items.next().?.* == 7);
assert(items.next().?.* == 9);
```


## Overview of key/value Map

Basic operations on the `LLRBTreeMap` of `u32` and `[]u8` is presented in the following:

```zig
var map = rbtree.llrbmap.LLRBTreeMap(u32, []u8).new(alloc, .{});
defer map.destroy();
// For adding a key/value pair, use `insert` function.
// The old value would be returned from the function if exists.
_ = try map.insert(5, try alloc.dupe(u8, "25"));

// the old value "25" is returned
var old = (try map.insert(5, try alloc.dupe(u8, "20"))).?;
defer alloc.free(old);
assert(mem.eql(u8, old, "25"));
assert((try map.insert(7, try alloc.dupe(u8, "28"))) == null);

// To lookup a value associated with a key from a map, use `get` function.
// `null` is returned if there is no value is associated with the key.
assert(mem.eql(u8, map.get(&@as(u32, 5)).?.*, "20"));
assert(map.get(&@as(u32, 10)) == null);

// To delete an entry, use `delete` function.
// The value associated with the key is returned from the function.
var deleted = map.delete(&@as(u32, 5)).?;
defer alloc.free(deleted);
assert(mem.eql(u8, deleted, "20"));
// a value associated with '5' have been deleted already
assert(map.delete(&@as(u32, 5)) == null);

_ = try map.insert(5, try alloc.dupe(u8, "20"));
_ = try map.insert(9, try alloc.dupe(u8, "36"));
// iterators enumerate values in ascending order
var kvs = map.iter();
var k0 = kvs.next().?;
assert(k0.key().* == 5 and mem.eql(u8, k0.value().*, "20"));
var k1 = kvs.next().?;
assert(k1.key().* == 7 and mem.eql(u8, k1.value().*, "28"));
var k2 = kvs.next().?;
assert(k2.key().* == 9 and mem.eql(u8, k2.value().*, "36"));
```


## Support

- zig 0.9.1
- zigmod r79

NOTICE: When you want to use Zig (> 0.9.1), use should use newer zigmod (> r79) too.


## Dependencies

- basis_concept (v1.1)
- iter


## Build

To build, executing the following commands:

```sh
zigmod fetch
zig build
```


## Unit Test

To performs unit tests:

```sh
zig build test
```


## Generate API documents

To generate documents:

```sh
zig build doc
```

Html documents would be generated under the `./doc` directory.


## Execute the example program

To execute the example program:

```sh
zig build example
```

The program is defined in `src/main.zig`.


## Module Hierarchy

`llrbset` and `llrbmap` are modules provided from the root of the library.
Each of these modules provides data structures: the `LLRBTreeSet` as a set of values and `LLRBTreeMap` as a key/value map.

- rbtree-zig (root)
  - llrbset
    - LLRBTreeSet  - A type of set of values
  - llrbmap
    - LLRBTreeMap  - A type of key/value map
  - ownership
    - Ownership


## Complexity

Basic operations provided by `LLRBTreeSet` and `LLRBTreeMap` are completed in _O(log(n))_ time for _n_ elements.

  |           |   get(i)|insert(i)|delete(i)|
  |LLRBTreeSet|O(log(n))|O(log(n))|O(log(n))|
  |LLRBTreeMap|O(log(n))|O(log(n))|O(log(n))|


