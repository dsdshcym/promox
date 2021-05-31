defprotocol Calculable do
  def add(a, b)
  def mult(a, b)
end

defprotocol ScientificCalculable do
  def exponent(a, b)
  def sin(a)
end
