% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/data_presentation.R
\name{h.render_plot}
\alias{h.render_plot}
\title{Render the desired weather data visualisation plot built with ggplot2}
\usage{
h.render_plot(records.df, plot.chr, sensor_name.chr)
}
\arguments{
\item{records.df}{A dataframe containing the records you wan to vizualize}

\item{plot.chr}{a character specifying the type of plot you want to build ("freq", "timeSerie", "scatter")}

\item{sensor_name.chr}{the name of the sensor data you want to plot}
}
\value{
an object of type plot
}
\description{
Render the desired weather data visualisation plot built with ggplot2
}
\author{
Thomas Goossens - pokyah.github.io
}
