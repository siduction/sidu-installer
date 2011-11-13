<?php
/**
 * The main module. Initializes the session, chooses and starts the needed plugin. 
 */
set_magic_quotes_runtime(0);
error_reporting(E_ALL);
include "base/session.php";
include "base/page.php";
include "base/userdata.php";
include "base/configuration.php";

$session = new Session();
$wait = $session->userData->getValue('wait', 'answer');
if (! empty ($wait)){
	if (strcmp($session->page, 'wait') != 0)
		$session->gotoPage('wait', 'install.wait');
}
$pagename = $session->page;
if (empty($pagename)){
	$pagename = 'home';
	$session->trace(TRACE_RARE, 'No page found');
}
$pageDefinition =  $session->homeDir . 'plugins/' . $pagename . 'page.php';
if (! file_exists($pageDefinition)){
	$session->trace(TRACE_RARE, "Not found: $pageDefinition");
	$session->gotoPage('home', 'install.no_page_def');
} else {
	include_once $pageDefinition;
	$classname = strtoupper(substr($pagename, 0, 1)) . substr($pagename, 1) . 'Page';
	$session->trace(TRACE_RARE, 'main: ' . $classname);
	$page = new $classname($session);
	
	$page->clearAllFieldErrors();
	
	$button = $session->hasButton();
	if (empty($button))
		$page->setFieldsFromUserData();
	else{
		$page->setFieldsFromHeader();
		if ($page->onButtonClick($button))
			$button = "";
	}
	if (empty($button)){
		$template = $page->getTemplateName();
		$pageText = $session->readFileFromBase($template, true);
		$session->trace(TRACE_RARE, 'nach readFileFromBase');
		$pageText = replaceTextMarkers($session, $pageText, $pagename);
		$session->trace(TRACE_RARE, 'nach replaceTextMarkers');
		$pageText = replaceInTemplate($session, $pagename, $pageText);
		$session->trace(TRACE_RARE, 'nach replaceInTemplate');
		
		$page->build();
		$session->trace(TRACE_RARE, 'nach build');
		$page->replaceTextMarkers();
		$session->trace(TRACE_RARE, 'nach replaceTextMarkers');
		$page->replaceMarkers();
		$session->trace(TRACE_RARE, 'nach replaceMarkers');
		$core = $page->getContent();
		$pageText = str_replace('###CONTENT###', $core, $pageText);
		
		$pageText = replaceGlobalMarkers($session, $pageText);	
		echo $pageText;
		$session->userData->write();
	}
}
/** Replaces the markers in the page template.
 * 
 * @param $session 	the session info
 * @param $pagename	the current page name 
 * @param $pageText	the template text
 * @return the template with expanded markers
 */
function replaceInTemplate(&$session, $pagename, $pageText){
	$prevPage = $session->getPrevPage($pagename);
	if ($prevPage == NULL)
		$button = '&nbsp;';
	else 
		$button = $session->configuration->getValue('.gui.button.prev');
	$pageText = str_replace('###BUTTON_PREV###', $button, $pageText);
				
	// Is this the last page?
	$nextPage = $session->getNextPage($pagename);
	if ($nextPage == NULL)
		$button = '&nbsp;';
	else 
		$button = $session->configuration->getValue('.gui.button.next');
	$pageText = str_replace('###BUTTON_NEXT###', $button, $pageText);
	$msg = $session->getMessage();
	$pageText = str_replace("###INFO###", $msg, $pageText);
	return $pageText;
}
/** Replaces the markers in the page template.
 * 
 * @param $session 	the session info
 * @param $pagename	the current page name 
 * @return the template with expanded markers
 */
function replaceGlobalMarkers(&$session, $pageText){
	$pageText = str_replace('###URL_STATIC###', $session->urlStatic, $pageText);
	$pageText = str_replace('###URL_FORM###', $session->urlForm, $pageText);
	$pageText = str_replace('###META_DYNAMIC###', $session->metaDynamic, $pageText);
	
	return $pageText;
}
	/** Replaces the text markers in the content with the translated text from the configuration.
	 */
function replaceTextMarkers(&$session, $pageText, $plugin){
	$start = 0;
	$end = 0;
	$rc = '';
	while ( ($start = strpos($pageText, '###txt_', $start)) > 0){
		$rc .= substr($pageText, $end, $start - $end);
		$end = $start + 7 + strspn($pageText, '_abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXZ01234567890', $start + 7);
		$end += strspn($pageText, '#', $end, 3);
		$marker = substr($pageText, $start, $end - $start);
		$key = trim($marker, '#');
		$value = $session->i18n($plugin, $key, '?%!');
		if (strcmp($value, '?%!') == 0)
			$value = $session->i18n('', $key, $key);
		$rc .= htmlentities($value, ENT_NOQUOTES, $session->charset);
		$start = $end;
	}
	$rc .= substr($pageText, $end);
	return $rc;	
}

?>