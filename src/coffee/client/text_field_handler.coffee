# This is an incredibly stateful, very "non reacty" object.
# TODO move the 'stateful' part outside react, make the react object more stateless

EditableTextField = (buildContent) -> React.createClass
    componentWillMount: ->
        @selection = []
        @text = @props.defaultText
        @baseText = @props.defaultText
        @stylingData = @props.stylingData

    render: ->
        <div contentEditable={true}
             onKeyDown={@updateSelection}
             onKeyUp={@updateSelection}
             onKeyPress={@updateSelection}
             onMouseUp={@updateSelection}
             onInput={@onTextChange}

             style={{'fontFamily': 'Courier New'}}
             id="across_clue"
             className="dont-bubble-keydown"

             ref="editableDiv" ></div>

    shouldComponentUpdate: (nextProps, nextState) ->
        @stylingData = nextProps.stylingData
        return false

    componentDidMount: ->
        @setContents @text

    updateSelection: () ->
        [selection, text] = @getSelectionAndText()
        @selection = selection

    onTextChange: () ->
        [newSelection, newText] = @getSelectionAndText()

        selection = @selection
        text = @baseText

        #try
        op = getOpForTextChange selection, text, newSelection, newText
        Utils.assert (newText == OtText.applyTextOp text, op)
        #catch
            # Fallback in case the complicated logic doesn't work
        #    asStr = (sel) ->
        #        "[#{("(#{a}, #{b})" for [a,b] in sel).join(", ")}]"

        #    op = OtText.text_diff2 text, newText

        @selection = newSelection
        @text = newText

        @props.produceOp op

    takeOp: (op) ->
        modelText = @baseText
        modelTextNew = OtText.applyTextOp modelText, op

        if modelTextNew == @text
            selection = @selection
        else if @baseText == @text
            # TODO OT the selection over the op
            selection = null
        else
            selection = null

        @setContents modelTextNew
        @setSelection selection

        @text = modelTextNew
        @baseText = modelTextNew
        @selection = selection

    getNode: ->
        React.findDOMNode(this.refs.editableDiv)

    setContents: (text) ->
        element = @getNode()
        while element.firstChild
            element.removeChild(element.firstChild)

        lineElements = buildContent (text.split "\n"), @stylingData

        for lineElement in lineElements
            element.appendChild lineElement

    setSelection: (selection) ->
        element = @getNode()

        countNewlines = (s) ->
            return (s.split "\n").length - 1
        getContOffset = (totalIndex) =>
            startOfLine = 1 + @text.lastIndexOf '\n', totalIndex-1
            offset = totalIndex - startOfLine
            containerIndex = countNewlines (@text.substr 0, startOfLine)
            container = element.childNodes[containerIndex]
            container2 = $(element).children().get(containerIndex)
            if offset == 0
                return [container, 0]
            else
                textNodes = get_text_nodes container
                i = 0
                while offset > $(textNodes[i]).text().length
                    Utils.assert(i < textNodes.length)
                    offset -= $(textNodes[i]).text().length
                    i += 1
                return [textNodes[i], offset]

        selObj = window.getSelection()
        selObj.removeAllRanges()
        for [left, right] in selection
            [contL, offsetL] = getContOffset left
            [contR, offsetR] = getContOffset right
            range = document.createRange()
            range.setStart contL, offsetL
            range.setEnd contR, offsetR
            selObj.addRange range

    getSelectionAndText: () ->
        element = React.findDOMNode(this)

        # Ugh, some annoying crap for traversing the DOM nodes for dealing
        # with the crazy way browsers interpret spaces.
        text_lines = []
        cur_line = []
        cur_line_has_text = false
        line_num = 0
        total_offset = 0

        add_line_piece = (node) ->
            node.lt_pieces = []
            text = $(node).text()
            if text.length > 0
                l = 0
                while l < text.length
                    if Utils.isWhitespace(text.charAt(l))
                        # run of spaces
                        r = l + 1
                        while r < text.length and Utils.isWhitespace(text.charAt(r))
                            r += 1
                        cur_line.push { node: node, left: l, right: r, text: " ", isSpace: true }
                    else
                        # run of text
                        r = l + 1
                        while r < text.length and not Utils.isWhitespace(text.charAt(r))
                            r += 1
                        cur_line.push {
                            node: node,
                            left: l,
                            right: r,
                            text: text.substring(l, r).replace('\xA0', ' '),
                            isSpace: false
                          }
                        cur_line_has_text = true
                    l = r
            else
                cur_line.push { node: node, left: 0, right: 0, text: "", isSpace: true }

        analyze_line_pieces = () ->
            while cur_line.length > 0 and cur_line[cur_line.length - 1].isSpace
                cur_line.length -= 1

            totalText = []
            for i in [0 ... cur_line.length]
                piece = cur_line[i]
                if piece.isSpace and (i == 0 or cur_line[i-1].isSpace)
                    piece.text = ""
                piece.totalOffset = total_offset
                total_offset += piece.text.length
                piece.node.lt_pieces.push piece
                totalText.push piece.text
            return totalText.join ""

        finish_line = () ->
            line_num++
            text_lines.push(analyze_line_pieces())
            cur_line = []
            cur_line_has_text = false
            total_offset += 1

        needs_newline = () ->
            return cur_line_has_text

        # Traverse the DOM nodes
        # Annotes all text nodes with `lt_pieces` 
        recurse = (elem) ->
            elem.lt_start_newline = false
            elem.lt_end_newline = false

            if elem.nodeType == 3 # is text node
                add_line_piece elem
            else if elem.nodeType == 1 # ordinary node
                if elem.tagName == "BR"
                    finish_line()
                    elem.lt_end_newline = true
                else
                    cssdisplay = $(elem).css('display')
                    is_inline = cssdisplay? and cssdisplay.indexOf('inline') != -1
                    if not is_inline and needs_newline()
                        finish_line()
                        elem.lt_start_newline = true

                    for childElem in $(elem).contents()
                        recurse childElem

                    if not is_inline and needs_newline()
                        finish_line()
                        elem.lt_end_newline = true

        recurse element

        if line_num == 0 or needs_newline()
            finish_line()

        # Traverse the DOM nodes again, annotate all nodes with lt_start and lt_end
        totalOffset = 0
        recurse2 = (elem) ->
            if elem.lt_start_newline
                totalOffset += 1
            elem.lt_start = totalOffset
            if elem.nodeType == 3 # is text node
                for piece in elem.lt_pieces
                    totalOffset += piece.text.length
            else if elem.nodeType == 1 # ordinary node
                for childElem in $(elem).contents()
                    recurse2 childElem
            elem.lt_end = totalOffset
            if elem.lt_end_newline
                totalOffset += 1

        recurse2 element

        # OK, now the text lines should be in `text_lines`.
        # Now we can use all the lt_* properties on the nodes to compute
        # the selection offsets.

        getTotalOffset = (container, offsetWithinContainer) ->
            if container.nodeType == 1
                return if offsetWithinContainer == 0 then container.lt_start else container.lt_end
            else if container.nodeType == 3
                for piece in container.lt_pieces
                    if offsetWithinContainer >= piece.left and offsetWithinContainer <= piece.right
                        return piece.totalOffset + Math.min(offsetWithinContainer - piece.left, piece.text.length)
                Utils.assert(false, "bad pieces")
            else
                Utils.assert(false, "nodeType note 1 or 3, instead " + container.nodeType)

        sels = []
        selObj = window.getSelection()
        for i in [0 ... selObj.rangeCount]
            range = selObj.getRangeAt(i)
            left = getTotalOffset(range.startContainer, range.startOffset)
            if left?
                right = getTotalOffset(range.endContainer, range.endOffset)
                if right?
                    sels.push [left, right]

        sels.sort ([l,r], [l2,r2]) -> l < l2
        return [sels, text_lines.join("\n")]


get_text_nodes = (el) ->
    ans = []
    recurse = (e) ->
        if e.nodeType == 1
            for node in e.childNodes
                recurse(node)
        else if e.nodeType == 3
            ans.push(e)
    recurse el
    return ans

getOpForTextChange = (old_sel, old_text, new_sel, new_text) ->
    Utils.assert old_sel.length >= 1
    Utils.assert new_sel.length == 1

    skip = OtText.skip; take = OtText.take; insert = OtText.insert

    op_delete_selected = [take old_sel[0][0]]
    length_after_delete = old_text.length
    for i in [0...old_sel.length]
        op_delete_selected.push (skip (old_sel[i][1] - old_sel[i][0]))
        op_delete_selected.push (take (((if i == old_sel.length - 1 then \
                old_text.length else old_sel[i+1][0]) - old_sel[i][1])))
        length_after_delete -= (old_sel[i][1] - old_sel[i][0])

    [l, r] = new_sel[0]
    if r > l
        Utils.assert new_text.length - (r - l) == length_after_delete
        op2 = [take(l), insert(new_text[l...r]), take(new_text.length-r)]
    else
        prefix_pre = old_sel[0][0]
        suffix_pre = length_after_delete - prefix_pre
        prefix_post = l
        suffix_post = new_text.length - l
        if prefix_pre == prefix_post
            if suffix_post > suffix_pre
                op2 = [take(prefix_pre), insert(new_text[prefix_pre...prefix_pre+suffix_post-suffix_pre]),
                       take(suffix_pre)]
            else
                op2 = [take(prefix_pre), skip(suffix_pre-suffix_post), take(suffix_post)]
        else if suffix_pre == suffix_post
            if prefix_post > prefix_pre
                op2 = [take(prefix_pre), insert(new_text[prefix_pre...prefix_post]), take(suffix_pre)]
            else
                op2 = [take(prefix_post), skip(prefix_pre-prefix_post), take(suffix_pre)]
        else
            throw "Does not match up on either side"

    op = OtText.composeText old_text,
                            (OtText.canonicalized op_delete_selected),
                            (OtText.canonicalized op2)
    return op

window.EditableTextField = EditableTextField
