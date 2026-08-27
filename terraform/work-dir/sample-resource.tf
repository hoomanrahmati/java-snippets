resource "terraform_data" "some_data" {
  # This is a placeholder for your Terraform data source configuration
  # You can define the necessary attributes and parameters here
  count = 5
  input = "hello ${count.index}"
  
}