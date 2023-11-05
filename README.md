# MachLoad
Machine Loader - A loading program contained in a boot sector written in 8086 assembly

# Screenshots
![machloader](https://github.com/SKauppinen/MachLoad/assets/11303257/6f403105-ecde-4813-879c-c7bf5f586a1a)
![machloader2](https://github.com/SKauppinen/MachLoad/assets/11303257/6c4b6873-3b18-4152-9f8c-bb9c551ea820)

# Features
*load function reads the first FAT12 file into 07e0:0000
*preview of binary data after loading
*error code following the error message if there is a read error
*auto-loading feature behaves like a boot loader. Runs UI if first entry in root dir is zero in size
*a loaded program can return to MachLoader using the iret instruction

# How to Use
The simplest way to use MachLoader is to write the provided image that comes with a sample program already loaded. The sample program prints keyboard scan codes into the attribute bytes of text memory making numbers of various colors appear on the screen. MachLoader loads the first file on the floppy so you can simply replace the binary file on the file system with one of your own and it will be loaded and executed. Windows will mess up file replacements and write a "System Volume Information" folder so I would avoid using a late version of Windows. Hard drive use hasn't been tried but MachLoader is intended to be used as a boot sector.
