TCGAPagesStream = require "../tcgaPagesStream"

describe "TCGA Pages Stream", ->

    it "should be a stream.", ->
        pagesStream = new TCGAPagesStream()
        expect(pagesStream.pipe).toBeDefined()

    it "accepts options", ->
        options = a: "b", c: 1
        pagesStream = new TCGAPagesStream options
        expect(pagesStream.options).toEqual options

    it "understands a rootURL option.", ->
        options = rootURL: "http://example.com"
        pagesStream = new TCGAPagesStream options
        expect(pagesStream.rootURL).toEqual options.rootURL

    it "initially has a paused queue with one item, the rootURL.", ->
        options = rootURL: "http://example.com"
        pagesStream = new TCGAPagesStream options
        q = pagesStream._q
        expect(q).toBeDefined()
        expect(q.length()).toBe 1
        expect(q.paused).toBe true
        expect(q.tasks[0].data).toBe options.rootURL

    describe "_read method", ->

        request = require "request"

        pagesStream = {}
        options = rootURL: "http://example.com"

        beforeEach ->
            pagesStream = new TCGAPagesStream options

        it "method reads from the rootURL", ->
            spy = spyOn request, "get"
                .andCallFake (options, callback) ->
                    callback? null, {request: uri: href: options.uri}, "Body"
            pagesStream._read()
            expect(spy).toHaveBeenCalled()
            expect(spy.mostRecentCall.args[0].uri).toEqual options.rootURL
            expect(spy.calls.length).toEqual 1

        it "queues links to subdirectories for reading.", (done) ->
            spy = spyOn pagesStream._q, "push"
                .andCallThrough()
            getSpy = spyOn request, "get"
                .andCallFake (new FakeGetter [rootHtml]).get
            pagesStream._read null, ->
                done()
            expect(spy).toHaveBeenCalled()
            expect(getSpy.calls.length).toBe 3

        it "recursively queues links to deeper subdirectories", (done) ->
            getSpy = spyOn request, "get"
                .andCallFake (new FakeGetter [rootHtml, accHtml]).get
            pagesStream._read null, ->
                done()
            expect(getSpy.calls.length).toBe 6

        it "calls @push with the returned objects", (done) ->
            spyOn pagesStream, "push"
                .andReturn true
            spyOn request, "get"
                .andCallFake (new FakeGetter [rootHtml, accHtml]).get
            pagesStream._read null, ->
                expect(pagesStream.push).toHaveBeenCalled()
                expect(pagesStream.push.calls.length).toBe 7
                done()

        it "pauses the queue if @push returns false", (done) ->
            spyOn pagesStream, "push"
                .andReturn false
            spyOn request, "get"
                .andCallFake (new FakeGetter [rootHtml, accHtml]).get
            pagesStream._read null, ->
                expect(pagesStream.push).toHaveBeenCalled()
                expect(pagesStream.push.calls.length).toBe 1
                expect(pagesStream._q.paused).toBe true
                done()

class FakeGetter
    constructor: (@responses) ->
        @count = 0
    get: (options, callback) => # fat arrow prevents rebinding
        response = @responses[@count++] or "Body"
        callback? null, {request: uri: href: options.uri}, response

rootHtml = """
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">
<html>
 <head>
  <title>Index of /tcgafiles/ftp_auth/distro_ftpusers/anonymous/tumor</title>
 </head>
 <body>
<h1>Index of /tcgafiles/ftp_auth/distro_ftpusers/anonymous/tumor</h1>
<pre>      <a href="?C=N;O=D">Name</a>                                           <a href="?C=M;O=A">Last modified</a>      <a href="?C=S;O=A">Size</a>  <hr>      <a href="/tcgafiles/ftp_auth/distro_ftpusers/anonymous/">Parent Directory</a>                                                    -   
      <a href="README_BCR.txt">README_BCR.txt</a>                                 2012-07-27 16:28  846   
      <a href="README_MAF.txt">README_MAF.txt</a>                                 2014-01-09 10:00  437   
      <a href="acc/">acc/</a>                                           2013-12-05 15:42    -   
      <a href="blca/">blca/</a>                                          2012-04-03 19:57    -   
<hr></pre>
</body></html>
"""

accHtml = """
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">
<html>
 <head>
  <title>Index of /tcgafiles/ftp_auth/distro_ftpusers/anonymous/tumor/acc</title>
 </head>
 <body>
<h1>Index of /tcgafiles/ftp_auth/distro_ftpusers/anonymous/tumor/acc</h1>
<pre>      <a href="?C=N;O=D">Name</a>                                                 <a href="?C=M;O=A">Last modified</a>      <a href="?C=S;O=A">Size</a>  <hr>      <a href="/tcgafiles/ftp_auth/distro_ftpusers/anonymous/tumor/">Parent Directory</a>                                                          -   
      <a href="bcr/">bcr/</a>                                                 2013-05-13 15:23    -   
      <a href="cgcc/">cgcc/</a>                                                2014-08-05 12:57    -   
      <a href="gsc/">gsc/</a>                                                 2014-03-03 22:37    -   
<hr></pre>
</body></html>
"""