var s_nextField = "";

// Sets the focus to the previous defined field.
// This routine must be called by timeout().
// Therefore a global variable must be used instead of a method parameter.
function nextField(){
	document.getElementsByName(s_nextField)[0].focus();
}	

// Click a button and set the focus to a given field.
// @param button:	name of the button to click
// @param field:    name of the field which gets the focus
function clickAndSet(button, field){
	s_nextField = field;
	window.setTimeout(nextField, 200);
	window.setTimeout(nextField, 1000);
	document.getElementsByName(button)[0].click();
}
// Clicks a button
// @param button:	name of the button to click
function autoClick(button){
	document.getElementsByName(button)[0].click();
}
	
	