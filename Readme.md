# LLRBTree for Zig: Set and Map container

This library provides kinds of container data structures: set of values and key/value map.
These containers are implemented with the Left Leaning Red-Black trees that is a BST (Balanced Binary Tree) algorithm.


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


## Generate docs

To generate documents:

```sh
zig build doc
```

Html documents would be generated under the `./doc` directory.


## Basic Usage

`llrbset` and `llrbmap` are modules provided from the root of the library.
Each of these modules provides data structures: the `LLRBTreeSet` as a set of values and `LLRBTreeMap` as a key/value map.


### Complexity

Basic operations provided by `LLRBTreeSet` and `LLRBTreeMap` are completed in _O(log(n))_ time for _n_ elements.

  |           |   get(i)|insert(i)|delete(i)|
  |LLRBTreeSet|O(log(n))|O(log(n))|O(log(n))|
  |LLRBTreeMap|O(log(n))|O(log(n))|O(log(n))|


### Set

- construct
- insert
- search
- delete
- iterating


- insert:
    For adding a value, use `insert` function.
    A pointer points the old value would be returned from the function if exists.

    ```zig
    const S = llrbset.LLRBTreeSet(u32, alloc);
    var set = S.new(.{});
    var i:u32 = 0;
    while (i < 10) : (i = i + 1) {
      set.insert(i);
    }
    assert(set.insert(5).?.* == 5); // the old value 5 is returned
    assert(set.insert(10) == null);
    ```

- search:
    To lookup a value from a set, use `get` function.
    `null` is returned if it is not exists in the set.

    ```zig
    const S = llrbset.LLRBTreeSet(u32, alloc);
    var set = S.new(.{});
    var i:u32 = 0;
    while (i < 10) : (i = i + 1) {
      set.insert(i);
    }
    assert(set.get(3).?.* == 3);
    assert(set.get(10) == null);
    ```

- delete:
    To delete a value, use `delete` function.
    Same as `insert`, the old value is returned from the function.

    ```zig
    const S = llrbset.LLRBTreeSet(u32, alloc);
    var set = S.new(.{});
    set.insert(3);
    assert(set.delete(&3).? == 3);
    assert(set.delete(&3) == null); // '3' have been deleted already
    ```


### Map

- construct
- insert
- search
- delete
- iterating



