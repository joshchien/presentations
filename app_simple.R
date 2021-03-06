##############################
# This is a simple shiny app.
# To run it, just press the "Run App" button on upper right of this panel.
##############################

##############################
# Below is the setup code that runs only once at startup 
# when the shiny app is started.
# In the setup code you can load packages, define functions 
# and variables, source files, and load data.

n_data <- 1e4
std_dev <- 1.0

# End setup code
##############################


##############################
## Define the user interface

inter_face <- shiny::fluidPage(
  # Create slider input for the input parameters
  numericInput('n_data', "Number of data points:", value=n_data),
  sliderInput("std_dev", label="Standard deviation:",
              min=0.1, max=3.0, value=std_dev, step=0.1),
  
  # Render plot in panel
  plotOutput("plo_t", height=500, width=500)
)  # end fluidPage interface



##############################
## Define the server function, with the arguments "input" and "output".
# The server function performs the calculations and creates the plots.

ser_ver <- function(input, output) {
  output$plo_t <- renderPlot({
    par(mar=c(2, 2, 4, 0), oma=c(0, 0, 0, 0))
    hist(rnorm(input$n_data, sd=input$std_dev), xlim=c(-4, 4),
         main="Histogram of Random Data")
  })  # end renderPlot
}  # end ser_ver


# Return a Shiny app object

shinyApp(ui=inter_face, server=ser_ver)
