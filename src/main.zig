/// Red-Black tree implementations.
///
/// # Modules
///
/// - `llrbset`
///   It is provided that a type of value container implemented by Left-leaning Red-Black Trees data structure.
/// - `llrbmap`
///   It is provided that a type of key/value mapping container implemented by Left-leaning Red-Black Trees data structure.
///
/// # Left-leaning Red-Black Trees (LLRB)
///
/// LLRB tree is a variant of Red-Black Tree.
/// This data structure restricts the form of the tree, then the number of tree operations are reduced compared to the naive Red-Black Tree.
///
/// Also, LLRB tree is a balanced search tree (BST).
/// Where the 'balanced' means that the ratio of the lenghs of all pathes is within a certain range.
/// More precisely, LLRB trees have the property that all pathes have exactly the same number of black links.
/// This is called Perfect Black Balance.
///
/// ## Complexity
///
/// By the Perfect Black Balance property.
/// For N elements, all operations are performed:
/// - Search: O(log(N))
/// - Insert: O(log(N))
/// - Delete: O(log(N))
///
/// # Cite
///
/// [^Sedgewick2008]: Robert Sedgewick, Left-leaning Red-Black Trees, 2008 https://sedgewick.io/wp-content/themes/sedgewick/papers/2008LLRB.pdf
///
pub const Self = @This();

/// A value container implemented by Left-leaning Red-Black Tree implementation.
///
/// # Details
/// This namespace provides a value container type `LLRBTreeSet` using LLRB Tree[^Sedgewick2008].
/// The container store values using an order relation defined to it.
pub const llrbset = @import("./llrbset/llrbset.zig");

/// A key/value mapping container implemented by Left-leaning Red-Black Tree implementation.
///
/// # Details
/// This namespace provides a key/value mapping container type `LLRBTreeMap` using LLRB Tree[^Sedgewick2008].
/// The container store key/value pairs using an order relation defined to the type of the keys.
/// Then, almost all operations are performed using a key given as a function argument.
pub const llrbmap = @import("./llrbmap/llrbmap.zig");

test {
    const std = @import("std");
    std.testing.refAllDecls(@This());
}
