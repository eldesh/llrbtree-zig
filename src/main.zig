/// Red-Black tree implementations.
pub const Self = @This();

/// A value container implemented by Left-leaning Red-Black Tree implementation. A variant of balanced search tree.
///
/// # Details
/// This module provides a value container type `LLRBTreeSet` which is a Left-leaning Red-Black Tree[^Sedgewick2008] (for short: LLRB tree) implementation.
/// LLRB tree is a variant of Red-Black Tree.
/// The LLRB tree restricts the form of the tree, then the number of tree operations are reduced compared to the naive Red-Black Tree.
/// 
/// # Properties
/// LLRB tree is a balanced search tree (BST).
/// Where the 'balanced' means that the ratio of the lenghs of all pathes is within a certain range.
/// More precisely, LLRB trees have the property that all pathes have exactly the same number of black links.
/// This is called Perfect Black Balance.
///
/// # Complexity
///
/// By the Perfect Black Balance property.
/// For N elements:
/// - Search: O(log(N))
/// - Insert: O(log(N))
/// - Delete: O(log(N))
///
/// # Cite
/// [^Sedgewick2008]: Robert Sedgewick, Left-leaning Red-Black Trees, 2008 https://sedgewick.io/wp-content/themes/sedgewick/papers/2008LLRB.pdf
pub const llrbset = @import("./llrbset/llrbset.zig");

test {
    const std = @import("std");
    std.testing.refAllDecls(@This());
}
