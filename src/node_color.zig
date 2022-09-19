pub const NodeColor = enum {
    Red,
    Black,

    pub fn flip(self: *@This()) void {
        switch (self.*) {
            .Red => self.* = .Black,
            .Black => self.* = .Red,
        }
    }
};
