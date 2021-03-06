##############################
# This is a shiny app for simulating a contrarian strategy 
# using returns scaled by the price range.
# 
# Just press the "Run App" button on upper right of this panel.
##############################

## Below is the setup code that runs once when the shiny app is started

# Load R packages
library(shiny)
library(dygraphs)
library(HighFreq)

## Model and data setup
# Uncomment the data you want to load

# Load the 5-second ES futures bar data collected from IB.
# data_dir <- "C:/Develop/data/ib_data/"
# sym_bol <- "ES"  # S&P500 Emini futures
# sym_bol <- "QM"  # oil
# load(paste0(data_dir, sym_bol, "_ohlc.RData"))

# Load 1-minute SPY bars
sym_bol <- "SPY"
oh_lc <- HighFreq::SPY

## Data setup
in_dex <- index(oh_lc)
n_rows <- NROW(oh_lc)
end_points <- xts::endpoints(oh_lc, on="hours")
clo_se <- Cl(oh_lc)[end_points]
re_turns <- HighFreq::diff_vec(log(drop(coredata(Cl(oh_lc)))))
re_turns <- c(0, re_turns)

## Scale the returns using the price range
rang_e <- log(drop(coredata(Hi(oh_lc)/Lo(oh_lc))))
# Average with the price range from previous bar
rang_e <- (rang_e + c(0, rang_e[-NROW(rang_e)]))/2
# returns_scaled <- re_turns
returns_scaled <- ifelse(rang_e>0, re_turns/rang_e, 0)


## Scale the returns using the volume
# vol_ume <- drop(coredata(Vo(oh_lc)))
# Average with the price range from previous bar
# vol_ume <- (vol_ume + c(0, vol_ume[-NROW(vol_ume)]))/2
# returns_scaled <- ifelse(vol_ume>0, re_turns/sqrt(vol_ume), 0)
# returns_scaled <- returns_scaled/sd(returns_scaled)


cap_tion <- paste("Contrarian Strategy for", sym_bol, "Using the Returns Scaled by the Price Range")

## End setup code


## Create elements of the user interface
inter_face <- shiny::fluidPage(
  titlePanel(cap_tion),
  
  fluidRow(
    # The Shiny App is re-calculated when the actionButton is clicked and the re_calculate variable is updated
    # column(width=12, 
    #        h4("Click the button 'Recalculate the Model' to re-calculate the Shiny App."),
    #        actionButton("re_calculate", "Recalculate the Model"))
  ),  # end fluidRow
  
  # Create single row with two slider inputs
  fluidRow(
    # Input end points interval
    # column(width=3, selectInput("inter_val", label="End points Interval",
    #                             choices=c("days", "weeks", "months", "years"), selected="days")),
    # Input look-back interval
    # column(width=3, sliderInput("look_back", label="Lookback", min=3, max=30, value=9, step=1)),
    # Input look-back lag interval
    column(width=3, sliderInput("lagg", label="lagg", min=1, max=5, value=4, step=1)),
    # Input threshold interval
    column(width=3, sliderInput("thresh_old", label="threshold", min=0.2, max=2.0, value=0.8, step=0.1)),
    # Input the weight decay parameter
    # column(width=3, sliderInput("lamb_da", label="Weight decay:",
    #                             min=0.01, max=0.99, value=0.1, step=0.05)),
    # Input model weights type
    # column(width=3, selectInput("typ_e", label="Portfolio weights type",
    #                             choices=c("max_sharpe", "min_var", "min_varpca", "rank"), selected="rank")),
    # Input number of eigenvalues for regularized matrix inverse
    # column(width=3, sliderInput("max_eigen", "Number of eigenvalues", min=2, max=20, value=15, step=1)),
    # Input the shrinkage intensity
    # column(width=3, sliderInput("al_pha", label="Shrinkage intensity",
    #                             min=0.01, max=0.99, value=0.1, step=0.05)),
    # Input the percentile
    # column(width=3, sliderInput("percen_tile", label="percentile:", min=0.01, max=0.45, value=0.1, step=0.01)),
    # Input the strategy coefficient: co_eff=1 for momentum, and co_eff=-1 for contrarian
    # column(width=3, selectInput("co_eff", "Coefficient:", choices=c(-1, 1), selected=(-1))),
    # Input the bid-offer spread
    column(width=3, numericInput("bid_offer", label="bid-offer:", value=0.00001, step=0.0001))
  ),  # end fluidRow
  
  # Create output plot panel
  mainPanel(dygraphOutput("dy_graph"), height=8, width=12)
  
)  # end fluidPage interface


## Define the server code
ser_ver <- function(input, output) {
  
  # Re-calculate the data and rerun the model
  da_ta <- reactive({
    # Get model parameters from input argument
    # look_back <- input$look_back
    lagg <- input$lagg
    # max_eigen <- isolate(input$max_eigen)
    thresh_old <- input$thresh_old
    # look_lag <- isolate(input$look_lag
    # lamb_da <- isolate(input$lamb_da)
    # typ_e <- isolate(input$typ_e)
    # al_pha <- isolate(input$al_pha)
    # percen_tile <- isolate(input$percen_tile)
    # co_eff <- as.numeric(isolate(input$co_eff))
    bid_offer <- input$bid_offer
    # Model is re-calculated when the re_calculate variable is updated
    # input$re_calculate

    
    # look_back <- 11
    # half_window <- look_back %/% 2
    
    # Rerun the model
    ## Backtest strategy for flipping if two consecutive positive and negative returns
    position_s <- rep(NA_integer_, n_rows)
    position_s[1] <- 0
    # Flip position if the scaled returns exceed thresh_old 
    position_s[returns_scaled > thresh_old] <- (-1)
    position_s[returns_scaled < (-thresh_old)] <- 1
    # LOCF
    position_s <- zoo::na.locf(position_s, na.rm=FALSE)
    position_s <- rutils::lag_it(position_s, lagg=lagg)
    # Calculate position turnover
    turn_over <- abs(rutils::diff_it(position_s)) / 2
    # Calculate number of trades
    # sum(turn_over)/NROW(position_s)
    # Calculate strategy pnl_s
    pnl_s <- (position_s*re_turns)
    # Calculate transaction costs
    cost_s <- bid_offer*turn_over
    pnl_s <- (pnl_s - cost_s)
    
    pnl_s <- cumsum(pnl_s)
    
    ## Coerce pnl_s to xts
    # pnl_s <- xts(pnl_s, in_dex)
    pnl_s <- cbind(pnl_s[end_points], clo_se)
    col_names <- c("Strategy", sym_bol)
    colnames(pnl_s) <- col_names
    pnl_s
  })  # end reactive code
  
  # Return to the output argument a dygraph plot with two y-axes
  output$dy_graph <- renderDygraph({
    col_names <- colnames(da_ta())
    dygraphs::dygraph(da_ta(), main=cap_tion) %>%
      dyAxis("y", label=col_names[1], independentTicks=TRUE) %>%
      dyAxis("y2", label=col_names[2], independentTicks=TRUE) %>%
      dySeries(name=col_names[1], axis="y", label=col_names[1], strokeWidth=1, col="red") %>%
      dySeries(name=col_names[2], axis="y2", label=col_names[2], strokeWidth=1, col="blue")
  })  # end output plot
  
}  # end server code

## Return a Shiny app object
shiny::shinyApp(ui=inter_face, server=ser_ver)
