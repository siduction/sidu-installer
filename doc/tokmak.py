#! /usr/bin/python
'''
Creates a table of content of an html document.

Created on 16.09.2011

@author: hm
'''
import re, sys

class TocMaker:
    def __init__(self, file):
        '''Constructor.
        @param file: name of the file
        '''
        self._file = file;
        self._beforeToc = None
        self._buffer = ''
        self._toc = '';
        self._stack = []
        self._curNo = None
        self._curLevel = None
        self._markerToc = "<!---===TOC===-->"
        self._inToc = False
        self._line = None
        self._error = False
        

        
    def buildPrefix(self):
        '''Builds a prefix for chapter enumerating.
        @param stack the stack of the chapter numbers
        @return: the string with the chapter numeration
        '''
        rc = ''
        for no in self._stack:
            rc += str(no) + '.'
        return rc

    def pop(self):
        '''Gets the last entry of the stack
        @return 0: empty stack. Otherwise: the top of the stack
        '''
        rc = 0
        if len(self._stack) == 0:
            self._error('empty stack')
        else:
            rc =self._stack.pop()
        return rc

    def replaceTopOfStack(self, top):
        '''Replaces the top of stack with a given number
        @param top: the new value
        '''
        self.pop()
        self._stack.append(top)
            
    def sameLevel(self):
        '''Handles a chapter with the same level as the predecessor.
        '''
        self._curNo += 1
        self.replaceTopOfStack(self._curNo)
        
    def higherLevel(self, level):
        '''Handles a chapter with a higher level as the predecessor.
        @param level    the new level
        '''
        self._curNo = 1
        while self._curLevel < level:
            self._stack.append(self._curNo)
            self._curLevel += 1
        
    def error(self, message):
        '''Prints an error message:
        @param messge:    the error message
        '''
        print message, ": ", self._line
        self._error = True
        
    def lowerLevel(self, level):
        '''Handles a chapter with a lower level as the predecessor.
        @param level    the new level
        '''
        while self._curLevel > level:
            if len(self._stack) <= 0:
                self.error('chapter number lower than first')
            else:
                self.pop()
            self._curLevel -= 1
            self._curNo = self.pop() + 1
            self._stack.append(self._curNo)
      
    def startTableOfContent(self):
        '''Builds the starting statements of the TOC.
        '''
        self._toc += self._markerToc + "\n"
        self._toc += "<div class=\"toc\">\n<ul>\n"
        
    def endTableOfContent(self):
        '''Builds the ending statements of the TOC.
        '''
        self._toc += "</ul>\n</div>\n"
        self._toc += self._markerToc + "\n"
        
    def addToToc(self, chapterNum, chapterName, title):
        '''Adds an entry to the table of content.
        @param chapterNum:     the enumeration of the chapter
        @param chapterName:    the name of the chapter (link anchor)
        @param title:          the title of the chapter 
        '''
        title = title.lstrip()
        line = '<li> <a href="#' + chapterName + '">' + chapterNum + ' ' + title + "</a></li>\n"
        self._toc += line
        
    def buildAnchor(self, chapterNum, chapterName):
        '''Builds the anchor used in the TOC.
        @param chapterNum:     the enumeration
        @param chapterName:    the chapter name (anchor for the link)
        '''
        rc = '<a name="' + chapterName + '">' + chapterNum + "</a>"
        return rc
        
    def handleHeadline(self, line, matcher):
        '''Handles a line containing the <hX> tag
        @param line:     the origin line
        @param matcher:  the rexpr matcher for the tag
        '''
        rexprEnd = re.compile(r'(<\s*/\s*[hH]\d+)')
        level = int(matcher.group(3))
        fullTag = matcher.group(1)
        hTag = matcher.group(2)
        if self._beforeToc == None:
            self._beforeToc = self._buffer
            self._buffer = ''
        if self._curLevel == None:
            self._curLevel = level
            self._curNo = 1;
            self._stack.append(self._curNo)
        elif level == self._curLevel:
            self.sameLevel()
        elif level < self._curLevel:
            self.lowerLevel(level)
        else : # level > curLevel
            self.higherLevel(level)
        chapterNum = self.buildPrefix();
        chapterName = 'C' + chapterNum.replace('.', '_');
        startTitle = line.find(fullTag) + len(fullTag)
        matcher2 = rexprEnd.search(line)
        if matcher2 == None:
            title = line[startTitle:]
        else:
            endTag = matcher2.group(1)
            endTitle = line.find(endTag);
            title = line[startTitle:endTitle]
        self.addToToc(chapterNum, chapterName, title)
        tag = hTag + self.buildAnchor(chapterNum, chapterName)
        line = line.replace(fullTag, tag)
        line = line.replace('    ', ' ');
        line = line.replace('  ', ' ');
        return line
        
    def parse(self):
        '''Parse the input file.
        '''
        self.startTableOfContent()
        rexpr = re.compile(r'((<[hH](\d+)[^>]*>)(<a name="C[0-9_]+">[0-9.]+</a>)?)');
        fp = open(self._file, "r")
        ok = False
        try:
            for line in fp:
                self._line = line
                hasMarker = line.find(self._markerToc) >= 0
                if hasMarker:
                    self._inToc = not self._inToc
                    continue
                if self._inToc:
                    continue
                matcher = rexpr.search(line)
                if matcher != None:
                    line = self.handleHeadline(line, matcher)
                self._buffer += line
            self.endTableOfContent()
            ok = True
        finally:
            fp.close()
            
        return ok
        
    def write(self):
        '''Writes the changed content to the file.
        '''
        if not self._error:
            name = self._file
            fp = open(name, "w")
            try:
                fp.write(self._beforeToc)
                fp.write(self._toc)
                fp.write(self._buffer)
                print "written:", name
            finally:
                fp.close()
        
if __name__ == '__main__':
    if len(sys.argv) < 2:
        print '''
Usage: tokmak.py <hfile>
Maintains the table of content of a html source.
<file>: the html file
Example: tokmak.py dev_documentation.html
        '''
    else:
        name = sys.argv[1]
        maker = TocMaker(name)
        if maker.parse():
            maker.write()
    
