<?php
/**
 * Builds the core content of the home page.
 * Implements a plugin.
 * 
 * @author hm
 */
class HomePage extends Page{
	/** Constructor.
	 * 
	 * @param $session
	 */
	function __construct(&$session){
		parent::__construct($session, 'home');
		$preloaded = $this->getUserData('preloaded');
		if (empty($preloaded)){
			$this->setUserData('preloaded', 'yes');
			$count = (int) $this->getConfiguration('preload.count');
			for ($ix = 0; $ix < $count; $ix++){
				$value = $this->getConfiguration("preload.$ix");
				list ($answer, $command, $param) = explode(CONFIG_SEPARATOR, $value);
				if (strpos($param, '|') > 0)
					$param = explode('|', $param);
				$opt = '';	
				if (strncmp($command, "&", 1) == 0){
					$opt = SVOPT_BACKGROUND;
					$command = substring($command, 1);
				}
				$this->session->exec($answer, $opt, $command, $param, 0);
			}
		}
	}
	/** Builds the core content of the page.
	 * 
	 * Overwrites the method in the baseclass.
	 */
	function build(){
		$this->readContentTemplate();
	}		
	/** Will be called on a button click.
	 * 
	 * @param $button	the name of the button
	 * @return false: a redirection will be done. true: the current page will be redrawn
	 */
	function onButtonClick($button){
		$rc = true;
		if (strcmp($button, 'button_next') == 0){
			$rc = $this->navigation(false);
		} elseif (strcmp($button, 'button_clear_config') == 0){
			$this->session->userData->clear();
		} else {
			$this->session->log("unknown button: $button");
		}
		return $rc;
	} 
}
?>