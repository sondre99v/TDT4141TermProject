********************************************************************************
files_for_the_pynq_card:   
  Follow the instructions in "files_for_the_pynq_card/README.txt" for uploading 
  the files to the PYNQ platform 

rsa_accelerator        :  rsa_accelerator files
********************************************************************************
rsa_accelerator/hdl    :  
  HDL code for a core with the exact same interface as needed for the final RSA 
  encryption core. 
  A good starting-point is to just edit the rsa_core.v file.

edit_rsa_accelerator   :  
********************************************************************************
  Folder for a project set up in order to edit the rsa_accelerator IP. 
  The folder contains only generated files in addition to the vivado project
  file. Click on the edit_rsa_accelerator.xpr file to start editing the 
  rsa_accelerator IP.

  Once you have changed the design and you think you are ready to integrate it 
  with the rest of the system, you have to take the following steps to package
  the IP: 

    1) Select in the Flow Navigator menu to the left:
       PROJECT MANAGER > Package IP
    2) Click on the "Review and Package" option in the "Packaging Steps" 
       menu. 
    3) Click "Re-Package IP"
    4) Done. You have now created an IP ready to be integrated with the rest of
       the system.

term_project
********************************************************************************
  Contains a vivado project where the rsa_accelerator is integrated as an IP.
  Use this project when generating bitfile for the PYNQ.

  Each time the rsa_accelerator IP is changed you have to go through the 
  following steps to create a new bitfile:
    1) Update the rsa_accelerator IP:
       Select in the menu bar at the top: "Reports>Report IP Status"
    2) At the bottom of the "IP Status" window that popped up:
       Select "Upgrade Selected". 
    3) In the Flow Navigator menu to the left:
       Click "Generate Bitstream". 
       This will take quite some time. Monitor the following: 
       a) The spinning green ring at the top right corner.
       b) The progress bar in the "Design Runs" tab
    4) When step 3) is complete you can locate and rename the bitfile in
       term_project\term_project.runs\impl_1 from rsa_soc_wrapper.bit to rsa_soc.bit
    5) select from the menu bar at the top: 
       "File > Export > Export block design"
       (Look at the Tcl Console and see that the command "write_bd_tcl -force path/to/rsa_soc.tcl" was run
    6) Install rsa_soc.tcl and rsa_soc.bit in the pynq/overlays/rsa_soc folder
       on the PYNQ board



