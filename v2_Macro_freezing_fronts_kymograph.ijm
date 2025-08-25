// Freezing front propagation study through kymograph
// author: cyril.bozonnet@inrae.fr
// with velocity measurement code taken from https://dev.mri.cnrs.fr/projects/imagej-macros/wiki/Velocity_Measurement_Tool
// date: August 2025

////////////////////////// File opening /////////////////////////////////
run("Close All");

// ask user to add filename and image parameters
Dialog.create("Open a raw temperature file");
Dialog.addFile("Raw File:", "", 130);
Dialog.addNumber("Width (pixels):", 640);
Dialog.addNumber("Height (pixels):", 480);
Dialog.addNumber("Number of Frames:", 2774);
Dialog.addNumber("Time Interval (s) :", 2);
Dialog.addNumber("delta Temp threshold (Celsius):", 0.2);
Dialog.show();

// Retrieve user input
filePath = Dialog.getString();
width = Dialog.getNumber();
height = Dialog.getNumber();
numImages = Dialog.getNumber();
dt = Dialog.getNumber();
TempThreshold = Dialog.getNumber();

// get file name and directory to save results
filename = File.getNameWithoutExtension(filePath);
dir = File.getDirectory(filePath);
outputPath = dir+File.separator + "ice_velocity_"+filename+".csv"

// open file and change color
run("Raw...", "open="+filePath+" image=[32-bit Real] width="+width+" height="+height+" number="+numImages+" little-endian");
run("Thermal");

// create results table and initialize line number
resultsTable = Table.create("Velocities");
row=0;

// Enter main loop with exit condition
done_main = false ;

while (!done_main) { // main loop for freezing events study
	
	///////////////////////////////////// stack selection ////////////////////////////
	
	// allow user to move within the stack
	waitForUser("Find a freezing event and remember frame interval before clicking OK");

	// ask frame interval
	Dialog.create("Create Substack - Enter frame interval");
	Dialog.addNumber("Start Frame:", 1);
	Dialog.addNumber("End Frame:", numImages);
	Dialog.addString("Substack Name:", "Branch1", 20);
	Dialog.show();
	startFrame = Dialog.getNumber();
    endFrame = Dialog.getNumber();
    stackname = Dialog.getString();
	
	// reslice
    run("Duplicate...", "duplicate range=" + startFrame + "-" + endFrame);
	rename(stackname);
	numSlices=nSlices; //get the number of slices
	
	// allow user to move within the stack
	setTool("rectangle");
	waitForUser("Use the rectangular tool to select the area around the event of interest then click OK");
	run("Crop");
	
	//////////////////////////////// difference computation /////////////////////////
	
	// create difference stack
	newImage("Differences of"+stackname, "32-bit black", getWidth(), getHeight(), 1);
	
	// get reference image
	selectImage(stackname);
    setSlice(1);
    run("Duplicate...", "use");
    rename("ref");
	
	// Loop through the stack starting from the second slice
	for (i = 2; i <= numSlices; i++) {
		showStatus("Computing differences...");

	    // Select the current and previous slices in the original stack
	    selectImage(stackname);
	    setSlice(i);
	    run("Duplicate...", "use");
	    rename("i+");
		    
	    // make substraction and add the result to the result stack
	    imageCalculator("Subtract create 32-bit stack", "i+", "ref");
	    rename("result");
	    run("Copy");
	  	selectWindow("Differences of"+stackname);
	  	run("Add Slice");
	  	run("Paste");
	  	
	  	// clean temporary images
	  	close("i+");
	  	close("result");
	}
	close("ref");
	run("Thermal");
	
	//////////////////////////////// Thresholding and cleaning /////////////////////////
	
	// perform simple thresholding
	setThreshold(TempThreshold, 1000000000000000000000000000000.0000);
	run("Convert to Mask", "background=Dark");
	run("Invert LUT");
	rename("thresholded");

	// clean the resulting image using binary opening
	run("Morphological Filters (3D)", "operation=Opening element=Ball x-radius=2 y-radius=2 z-radius=0");
	rename("cleaned");
	close("thresholded");
	
	/////////////////////////////////// Kymograph //////////////////////////////////

	// ask user to draw a line
	setTool("line");
	waitForUser("Draw a straight line where you want to create a kimogram, then press OK");

	// create kimogram and threshold it
	run("Reslice [/]...", "output=0.000 start=Top avoid");
	setThreshold(1, 256);
	run("Convert to Mask", "background=Dark");
	run("Invert LUT");
	rename("kymograph");
	
	// show its edges for better velocity computation
	//run("Find Edges");
	
	//////////////////////////////////// Velocity measurements /////////////////////
	//https://forum.image.sc/t/line-selection-tool-for-kymograph-velocity-measurement/32723
	done_velocity = false;
	
	while (!done_velocity) {
			// ask user to draw line(s)
			waitForUser("Draw a straight  or segmented line within the kymograph, then press OK") ;
			
			getSelectionCoordinates(x, y);
			
			for (i=0; i<x.length-1; i++){
				dx_now=abs(x[i+1]-x[i]);
				dy_now=abs(y[i+1]-y[i]);
				vel =dx_now/dy_now;
				
				// Add results to the table
				Table.set("Names", row,stackname);
				Table.set("Velocities [space unit / s]", row,vel/dt);
				Table.update;
				row++;
			}	

			// ask for end condition
			Dialog.create("Continue with this kymograph?");
			Dialog.addCheckbox("Click here to go to next freezing event", false);
			Dialog.show();
			done_velocity = Dialog.getCheckbox();
	}


	// clean before next freezing event
	close(stackname);

	close("cleaned");
	close("kymograph");
	
	// ask for end condition
	Dialog.create("Continue?");
	Dialog.addCheckbox("Click here to stop main loop", false);
	Dialog.show();
	done_main = Dialog.getCheckbox();
}

Table.save(outputPath);
close("*");
