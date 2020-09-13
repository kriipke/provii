# provii

`provii` is a command-line utility installer that is written in pure bash. The design goals are:
 - *minimal footprint*: provii itself along with the tools it installs should be extremely easy to keep track of on your filesystem and consequently easy to remove
 - *minimal dependencies*: to keep things portable as well as keep the footprint to a minimum provii is designed to install binary applications via it's installation scripts 
 - *minimal privilages required*: you should be able to run these installations as any user with the option of installing them system wide if you run provii with root privilages.

## usage

`provii` is actually easiest to use without installing it at all. You can browse the `provii` Github repository for availiable installation scripts for well-known, self-contained cli-applications: [github.com/l0xy/provii/tree/master/installs](https://github.com/l0xy/provii/tree/master/installs) 

Once you find something you're interested in, say `kmon` - a utility for monitoring loaded kernel modules, you can simply run the following in your terminal:
`bash -c "$(curl https://l0xy.sh/provii.sh)" kmon` 

Replace `kmon` in this example with any other installer script you find in the `./installers/` directory, enjoy the free software provided by the amazing programmers who created these cli-tools! (See below for more info)
