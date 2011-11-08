<?php
/**
 * Builds the core content of the last page which runs the installation.
 * Implements a plugin.
 * 
 * @author hm
 */
class RunPage extends Page{
	/** Constructor.
	 * 
	 * @param $session
	 */
	function __construct(&$session){
		parent::__construct($session, 'run');
		$this->setDefaultOption('force', 0, true);
		$this->setReplacement('###BUTTON_OR_INFO###', 
			$this->getConfiguration('button'), false);
		$rootfs = $session->userData->getValue('rootfs', 'root');
		$this->setReplacement('###ROOT_FS###', $rootfs);
	}
	/** Returns an array containing the input field names.
	 * 
	 * @return an array with the field names
	 */
	function getInputFields(){
		$rc = array('force');
		return $rc;
	}
	/** Builds the core content of the page.
	 * 
	 * Overwrites the method in the baseclass.
	 */
	function build(){
		$this->readContentTemplate();
		$this->fillOptions('force');
		return $this->content;
	}	
	/** Sends a request to the shell server and go into wait state.
	 */
	function startInstallation(){
		$answer = $this->session->getAnswerFileName('inst', '.ready');
		$shellConfig = $this->session->getAnswerFileName('inst', '.conf');
		$lines = array();
		$lines[] = "REGISTERED=' SYSTEM_MODULE HD_MODULE HD_FORMAT HD_FSTYPE HD_CHOICE HD_MAP HD_IGNORECHECK SWAP_MODULE SWAP_AUTODETECT SWAP_CHOICES NAME_MODULE NAME_NAME USER_MODULE USER_NAME USERPASS_MODULE USERPASS_CRYPT ROOTPASS_MODULE ROOTPASS_CRYPT HOST_MODULE HOST_NAME SERVICES_MODULE SERVICES_START BOOT_MODULE BOOT_LOADER BOOT_DISK BOOT_WHERE AUTOLOGIN_MODULE INSTALL_READY HD_AUTO'";
		$lines[] = '';
		$lines[] = "SYSTEM_MODULE='configured'";
		$lines[] = "HD_MODULE='configured'";
		$lines[] = '';
		
		$description = $this->getConfiguration('description_wait'); 
		$program = 'installation';
		$progress = $this->session->getAnswerFileName('progress', '.dat');
		$params = array();
		$params[] = "progress=$progress";
		$params[] = "configfile=$shellConfig";
		
		$curValue = $this->session->userData->getValue('rootfs', 'root');
		$params[] = "rootpart=$curValue";
		$lines[] = "# Here the siduction-System will be installed";
		$lines[] = "# This value will be checked by function module_hd_check";
		$lines[] = "HD_CHOICE='$curValue'";
		$lines[] = "";
		
		
		$curValue = $this->session->userData->getValue('rootfs', 'filesys');
		$ix = $this->indexOfList('rootfs', 'filesys', NULL, 'opt_filesys');
		if ($ix <= 0) 
			$curValue = '-';
		$lines[] = "# Determines if the HD should be formatted. (mkfs.*)";
		$lines[] = "# Possible are: yes|no";
		$lines[] = "# Default value is: yes";
		$value = strcmp($curValue, "-") == 0 ? 'no' : 'yes';
		$lines[] = "HD_FORMAT='$value'";
		$lines[] = '';

		$params[] = 'rootfs=' . $curValue;
		
		$lines[] = "# Sets the Filesystem type.";
		$lines[] = "# Possible are: ext3|ext4|ext2|reiserfs|jfs";
		$lines[] = "# Default value is: ext4";
		$lines[] = "HD_FSTYPE='$curValue'";

		$count = $this->session->userData->getValue('mountpoint', 'mounts.rowcount');
		$mounts = '';
		$map = "";
		for ($ix = 0; $ix < $count; $ix++){
			$value = $this->session->userData->getValue('mountpoint', "mounts.row$ix");
			// /dev/sda9|data|ext4|/data|BUTTON_DEL_1
			$list = explode('|', $value);
			$mounts .= ';' . $list[0] . '|' . $list[3] . '|' . $list[2] . '|' . $list[1];
			$map .= ' ' . $list[0] . ':' . $list[3];
		}
		$params[] = substr($mounts, 1);
		$lines[] = "# Here you can give additional mappings. (Experimental) You need to have the partitions formatted yourself and give the correct mappings like: /dev/hda4:/boot /dev/hda5:/var /dev/hda6:/tmp";
		$lines[] = "HD_MAP='$map'";
		$lines[] = "";
		
		$lines[] = "# If set to yes, the program will NOT check if there is enough space to install sidux on the selected partition(s). Use at your own risk! Useful for example with HD_MAP if you only have a small root partition.";
		$lines[] = "# Possible are: yes|no";
		$lines[] = "# Default value is: no";
		$ix = $this->indexOfList('run', 'force', NULL, 'opt_force');
		$params[] = "force=$ix";
		$curValue = $ix == 0 ? 'no' : 'yes';
		$lines[] = "HD_IGNORECHECK='$curValue'";
		$lines[] = "";
		
		$lines[] = "SWAP_MODULE='configured'";
		$lines[] = "# If set to yes, the swap partitions will be autodetected.";
		$lines[] = "# Possible are: yes|no";
		$lines[] = "# Default value is: yes";
		$lines[] = "SWAP_AUTODETECT='yes'";
		$lines[] = "";
		
		$lines[] = "# The swap partitions to be used by the installed siduction.";
		$lines[] = "# This value will be checked by function module_swap_check";
		$lines[] = "SWAP_CHOICES='__swapchoices__'";
		$lines[] = "";
		
		$curValue = $this->session->userData->getValue('user', 'real_name');
		$params[] = "username=$curValue";
		 
		$lines[] = "NAME_MODULE='configured'";
		$lines[] = "NAME_NAME='$curValue'";
		$lines[] = "";
		
		$curValue = $this->session->userData->getValue('user', 'name');
		$params[] = "login=$curValue"; 
		$lines[] = "USER_MODULE='configured'";
		$lines[] = "USER_NAME='$curValue'";
		$lines[] = "";
				
		$curValue = $this->session->userData->getValue('user', 'pass');
		$params[] = "pw=$curValue"; 
		$lines[] = "USERPASS_MODULE='configured'";
		$lines[] = "USERPASS_CRYPT='$curValue'";		
			
		$curValue = $this->session->userData->getValue('user', 'root_pass');
		$params[] = "rootpw=$curValue"; 
		$lines[] = "ROOTPASS_MODULE='configured'";
		$lines[] = "ROOTPASS_CRYPT='$curValue'";
		
		$curValue = $this->session->userData->getValue('network', 'host');
		$params[] = "hostname=$curValue"; 
		$lines[] = "HOST_MODULE='configured'";
		$lines[] = "HOST_NAME='$curValue'";
		$lines[] = "";
		
		$services = "cups";
		$ix = $this->indexOfList('network', 'ssh', NULL, 'opt_ssh');
		$params[] = "ssh=$ix";
		if ($ix == 1)
			$services .= " ssh";
		$lines[] = "SERVICES_MODULE='configured'";
		$lines[] = "# Possible services are for now: cups smail ssh samba (AFAIK this doesnt work anymore)";
		$lines[] = "# Default value is: cups";
		$lines[] = "SERVICES_START='$services'";
		$lines[] = "";
			
		
		$ix = $this->indexOfList('boot', 'loader', NULL, 'opt_loader');
		$curValue = ($ix == 0 ? "-" : $this->session->userData->getValue('boot', 'loader'));
		$curValue = strtolower($curValue);
		$params[] = "bootmanager=$curValue"; 
		$lines[] = "BOOT_MODULE='configured'";
		$lines[] = "# Chooses the Boot-Loader";
		$lines[] = "# Possible are: grub";
		$lines[] = "# Default value is: grub";
		$lines[] = "BOOT_LOADER='$curValue'";
		$lines[] = "";
		
		$lines[] = "# If set to 'yes' a boot disk will be created! (AFAIK this doesnt work anymore)";
		$lines[] = "# Possible are: yes|no";
		$lines[] = "# Default value is: yes";
		$lines[] = "BOOT_DISK='no'";
		$lines[] = "";
		
		$ix = $this->indexOfList('boot', 'target', NULL, 'opt_target');
		$curValue = ($ix == 0 ? 'mbr' : 'partition');
		$params[] = "bootdest=$curValue"; 
		$lines[] = "# Where the Boot-Loader will be installed";
		$lines[] = "# Possible are: mbr|partition";
		$lines[] = "# Default value is: mbr";
		$lines[] = "BOOT_WHERE='$curValue'";
		$lines[] = "";
		
		$params[] = 'timezone=' . $this->session->userData->getValue('boot', 'region')
			. '/' . $this->session->userData->getValue('boot', 'city');
		
		$lines[] = "AUTOLOGIN_MODULE='configured'";
		$lines[] = "INSTALL_READY='yes'";
		$lines[] = "";
		$lines[] = "# mount partitions on boot. Default value is: yes";
		$ix = $this->indexOfList('mountpoint', 'mountonboot', NULL, 'opt_mountonboot');
		$params[] = "mountonboot=$ix";
		$curValue = $ix == 0 ? 'no' : 'yes';
		$lines[] = "HD_AUTO='$curValue'";
		$lines[] = "";


		$configFile = fopen($shellConfig, "w");
		foreach ($lines as $key => $val) {
			$val .= "\n";
			fputs($configFile, $val);
		}
		fclose($configFile);
		
		$options = 'background requestfile';
		$command = 'install';
		
		$this->session->exec($answer, $options, $command, $params, 0);
		$redraw = $this->startWait($answer, $program, $description, $progress);

	}	
	/** Will be called on a button click.
	 * 
	 * @param $button	the name of the button
	 * @return false: a redirection will be done. true: the current page will be redrawn
	 */
	function onButtonClick($button){
		$rc = true;
		$value = $this->session->getField('running');
		if (! empty($value))
		{
			$text = $this->getConfiguration('info_running');
			$this->setReplacement('###BUTTON_OR_INFO###', $text, false);
		}
			
		if (strcmp($button, 'button_install') == 0){
			$this->session->userData->setValue('run', 'running', 'T');
			$this->setField('running', 'T');
			$this->startInstallation();
		}
		elseif (strcmp($button, 'button_prev') == 0){
			$page = $this->session->getPrevPage('run');
			$this->session->gotoPage($page, 'run.next');
			$rc = false;
		} else {
			$this->session->log("unknown button: $button");
		}
		return $rc;
	} 
}
?>