resource "aws_subnet" "public" {

  count = length(var.vpc.public_subnet)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.vpc.public_subnet[count.index].cidr_block
  availability_zone       = var.vpc.public_subnet[count.index].availability_zone
  map_public_ip_on_launch = var.vpc.public_subnet[count.index].map_public_ip_on_launch



  tags = { Name = "${var.vpc.name}-${var.vpc.public_subnet[count.index].name}" }

}
