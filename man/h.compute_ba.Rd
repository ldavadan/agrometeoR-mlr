% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/computation_and_manipulation.R
\name{h.compute_ba}
\alias{h.compute_ba}
\title{Compute either a Bland-Altman plot or Bland-Altman stats dataframe}
\usage{
h.compute_ba(records.wide.df, output.chr)
}
\arguments{
\item{records.wide.df}{A wide dataframe containing the records you wan to submit to BA analysis}

\item{output.chr}{a character specifying the type of output you want ("plot" or "table")}

\item{sensor_name.chr}{the name of the sensor data you want to plot}
}
\value{
either a BA plot or table
}
\description{
Compute either a Bland-Altman plot or Bland-Altman stats dataframe
}
\author{
Thomas Goossens - pokyah.github.io
}
