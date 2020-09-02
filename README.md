# provii

This is a little command-line utility installer that is written in pure bash. The design goals are:
 - *minimal footprint*: provii itself along with the tools it installs should be extremely easy to keep track of on your filesystem and consequently remove
 - *minimal dependencies*: to keep things portable as well as keep the footprint to a minimum provii is designed to install binary applications via it's installation scripts 
 - *minimal privilages required*: you should be able to run these installations as any user with the option of installing them system wide if you have access to directories like `/usr/local/bin`

## installation

`provii` is actually easiest to use without installing it at all. Instead browse the `./installs/` directory in the `provii` repository for availiable installation scripts for well-known, self-contained cli-applications: [github.com/l0xy/provii/tree/master/installs](https://github.com/l0xy/provii/tree/master/installs) 
## writing scripts

Once you find something you're interested in, say `kmon` - a utility for monitoring loaded kernel modules, you can simply run the following in your terminal:
`bash -c "$(curl -#L https://l0xy.sh/provii.sh)" kmon` 

Replace `kmon` in this example with any other installer script you find in the `./installers/` directory, enjoy the free software provided by the amazing programmers who created these cli-tools! (See below for more info)

### provii variables

TO BE DOCUMENTED..
( _check out the variables in `./provii.conf` to get a feel for the special provii variables_ )

### provii functions

TO BE DOCUMENTED..
( _check out the files in `./installs/` to get a feel for some of the special provii functions_ )
