The files in this folder must be moved over to the filesystem on the PYNQ board as follows: 

mv /crypto                        ddspynq<nn>/pynq/.
mv "RSA Integration Kit.ipynb"    ddspynq<nn>/jupyter_notebooks
mv /rsa_soc                       ddspynq<nn>/pynq/overlays/.

RSA
inp_messages is the messages inputes
otp_hw_messages is the output messages which are outputed hw
otp_sw_messages is the output messages which are outpute sw

XOR
TO GET CIPHER TEXT, TO HAVE A STARTING POINT I GUESS??

Overlays is the destination for the rsa_soc, the bit files is the programming thingy.
Tcl is the file contains informations about the bit files, it gives the software stack info about
registers, dma, and how they are mapped to the adressrange

The integration kit text can be edited, we can go from XOR to RSA by changing the constant
C_ENCR_ALGORITHM = C_ENCR_ALGORITHM_XOR/RSA