# SCRIPT: collectl.r
# AUTHOR: Anibal Santiago - @SQLThinker
# DATE:   2019-01-24
#
# DESCRIPTION: Sample script to generate plots from a CSV file
#
# The data was generated using the collectl command (http://collectl.sourceforge.net/)
# in a Linux server
#
#  collectl -scdm -i 15 -R 8m -P -f /tmp/sample-test.csv
#    -scdm: Data to be collected: c:CPU; d:Disk; m:Memory
#    -i : Take a sample ever 15 seconds
#    -R : Run for 8 minutes
#    -P : Generate output in plot format
#
# Note: Make sure to set your working directory like setwd("C:\\Temp") to match the location
#       of the CSV file       


# Read the data from the CSV file
rawdata <- read.csv("sample-test.csv", header=TRUE, sep=",", colClasses="character")

# Filename to save the plots
pdffile = "load-test-summary.pdf"

# Metrics to plot: IO Requests per Second and Total CPU
# Format them as Numeric as we read them as character
rawdata$X.DSK.OpsTot <- as.numeric(rawdata$X.DSK.OpsTot)
rawdata$X.CPU.Totl. <- as.numeric(rawdata$X.CPU.Totl.)

# Save output as PDF file
pdf(file = pdffile, width = 12, height = 3, useDingbats=FALSE)

# Generate the first plot
p1 = ggplot(data=rawdata, aes(x =Time, y = X.DSK.OpsTot, group=1)) +
  geom_bar(stat="identity", fill="steelblue") + 
  ylab("I/O Requests per Sec") +
  theme(axis.title.x=element_blank(), axis.text.x=element_blank(), axis.ticks.x=element_blank())
print(p1)

# Generate second plot
p2 = ggplot(data=rawdata, aes(x =Time, y = X.CPU.Totl., group=1)) +
  geom_line(color="red") + 
  ylab("CPU") +
  theme(axis.title.x=element_blank(), axis.text.x=element_blank(), axis.ticks.x=element_blank())
print(p2)

# Close the PDF file device
dev.off()

