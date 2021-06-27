require Promox

# Test that we can pass a variable to `:for` option
protocol_mod = Calculable
Promox.defmock(for: protocol_mod)
Promox.defmock(for: ScientificCalculable)
