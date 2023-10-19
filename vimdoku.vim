function! s:init()
	enew

	let s:rowCount = 9
	let s:colCount = 9
	let s:boxCount = 9
	let s:boxRowCount = 3
	let s:boxColCount = 3

	let s:height = 13
	let s:width = 25

	let s:topOffset = (winheight("%") - s:height) / 2
	let s:leftOffset = (winwidth("%") - &numberwidth - s:width) / 2

	let s:rowHighlights = {}
	let s:colHighlights = {}
	let s:boxHighlights = {}
	let s:dupHighlights = {}

	let s:isValid = 1

	highlight Valid ctermbg=green guibg=green
	highlight Invalid ctermbg=red guibg=red

	let l:onTextChanged = {}
	let l:onTextChanged.bufnr = bufnr("%")
	let l:onTextChanged.event = ['TextChanged', 'TextChangedI']
	let l:onTextChanged.cmd = 'Validate'

	let l:onBufLeave = {}
	let l:onBufLeave.bufnr = bufnr("%")
	let l:onBufLeave.event = ['BufLeave']
	let l:onBufLeave.cmd = 'call clearmatches()'

	call autocmd_add([l:onTextChanged, l:onBufLeave])

	call <SID>drawBoard()
	call <SID>addPlaceholders()
	call <SID>setCursorPos(<SID>mapFieldIndexToBufferPos([0, 0]))
endfunction

function! s:drawBoard()
	call <SID>insertEmptyLines(s:topOffset + s:height)

	execute (s:topOffset + 1) .. ",$call <SID>addHorizontalPadding()"

	for i in range(1, s:height, 4)->map('s:topOffset + v:val')
		execute i .. "call <SID>drawVerticalSeparator()"
	endfor

	for i in range(2, s:height, 4)->map('s:topOffset + v:val')
		execute i .. "," .. (i + 2) .. "call <SID>drawRow()"
	endfor
endfunction

function! s:insertEmptyLines(count)
	execute "normal! " .. (a:count - 1) .. "o\<esc>"
endfunction

function! s:addHorizontalPadding()
	execute "normal! I\<space>\<esc>yl" .. (s:leftOffset - 1) .. "p$"
endfunction

function! s:drawRow()
	execute "normal! A|\<space>\<esc>yl6pF|y$$2pA|\<esc>"
endfunction

function! s:drawVerticalSeparator()
	execute "normal! A+-\<esc>yl6pF+yg_$2pA+\<esc>"
endfunction

function! s:mapFieldIndexToBufferPos(index)
	let l:y = s:topOffset + a:index[1] + (a:index[1] / 3) + 2
	let l:x = s:leftOffset + 2*a:index[0] + 2*(a:index[0] / 3) + 3

	return [l:x, l:y]
endfunction

function! s:addPlaceholders()
	for y in range(0, s:rowCount - 1)
		for x in range(0, s:colCount - 1)
			let l:pos = <SID>mapFieldIndexToBufferPos([x, y])
			call <SID>setCursorPos(l:pos)
			normal! r#
		endfor
	endfor
endfunction

function! s:setCursorPos(pos)
	execute "normal! " .. a:pos[1] .. "G" .. a:pos[0] .. "|"
endfunction

function! s:getValues()
	let l:values = []
	
	let save_cursor = getcurpos()
	for y in range(0, s:rowCount - 1)
		let l:values = add(l:values, [])
		for x in range(0, s:colCount - 1)
			let l:pos = <SID>mapFieldIndexToBufferPos([x, y])
			call <SID>setCursorPos(l:pos)
			let l:values[y] += [getline('.')[col('.') - 1]]
		endfor
	endfor
	call setpos('.', save_cursor)

	return l:values
endfunction

function! s:setFieldValue(index, value)
	let save_cursor = getcurpos()

	let l:pos = <SID>mapFieldIndexToBufferPos(a:index)
	call <SID>setCursorPos(l:pos)
	execute "normal! r" .. a:value

	call setpos('.', save_cursor)
endfunction

function! s:findNextEmptyField(values, ...)
	let [l:x, l:y] = get(a:, 1, [0, 0])

	while l:x < s:colCount && l:y + 1 < s:rowCount && a:values[l:y][l:x] != '#'
		if l:x + 1 < s:colCount
			let l:x += 1
		else
			let l:y += 1
		endif
	endwhile

	return a:values[l:y][l:x] == '#' ? [l:x, l:y] : [-1, -1]
endfunction

function! s:getRowFieldIndexes(rowIndex)
	let [l:x, l:y] = [0, a:rowIndex]
	let l:indexes = []

	for dx in range(0, s:rowCount - 1)
		let l:indexes = add(l:indexes, [l:x + dx, l:y])
	endfor

	return l:indexes
endfunction

function! s:getColFieldIndexes(colIndex)
	let [l:x, l:y] = [a:colIndex, 0]
	let l:indexes = []

	for dy in range(0, s:colCount - 1)
		let l:indexes = add(l:indexes, [l:x, l:y + dy])
	endfor

	return l:indexes
endfunction

function! s:getBoxFieldIndexes(boxIndex)
	let [l:x, l:y] = [3 * (a:boxIndex % 3), 3 * (a:boxIndex / 3)]
	let l:indexes = []

	for dy in range(0, s:boxRowCount - 1)
		for dx in range(0, s:boxColCount - 1)
			let l:indexes = add(l:indexes, [l:x + dx, l:y + dy])
		endfor
	endfor

	return l:indexes
endfunction

function! s:validate(values)
	" Handle invalid characters
	for y in range(0, s:rowCount - 1)
		for x in range(0, s:colCount - 1)
			if a:values[y][x] != '#' && (a:values[y][x] < 1 || a:values[y][x] > 9)
				echohl ErrorMsg
				echomsg "Invalid value '" .. a:values[y][x] .. "'"
				echohl None
				call <SID>setFieldValue([x, y], '#')
			endif
		endfor
	endfor

	let l:fieldsStatus = []
	for i in range(0, s:rowCount*s:colCount - 1)
		let l:fieldsStatus = add(l:fieldsStatus, 1)
	endfor

	" Check horizontally
	let l:rowsStatus = <SID>validateComponent(
				\ a:values,
				\ s:rowCount,
				\ '<SID>getRowFieldIndexes',
				\ l:fieldsStatus)

	" Check vertically
	let l:colsStatus = <SID>validateComponent(
				\ a:values,
				\ s:colCount,
				\ '<SID>getColFieldIndexes',
				\ l:fieldsStatus)

	" Check boxes
	let l:boxesStatus = <SID>validateComponent(
				\ a:values,
				\ s:boxCount,
				\ '<SID>getBoxFieldIndexes',
				\ l:fieldsStatus)

	call <SID>updateHighlights(l:rowsStatus, l:colsStatus, l:boxesStatus, l:fieldsStatus)

	let s:isValid = !(index(l:fieldsStatus, 0) >= 0)
endfunction

function! s:validateComponent(values, count, indexGenerator, fieldsStatus)
	let l:compStatus = []
	for i in range(0, a:count - 1)
		let l:compStatus = add(l:compStatus, 1)
	endfor

	for compIndex in range(0, a:count - 1)
		let l:occurences = {}
		for [l:x, l:y] in function(a:indexGenerator)(compIndex)
			let l:val = a:values[l:y][l:x]
			if ! has_key(l:occurences, l:val)
				let l:occurences[l:val] = [[l:x, l:y]]
			else
				let l:occurences[l:val] = add(l:occurences[l:val], [l:x, l:y])
			endif
		endfor
		for i in range(1, 9)
			if len(get(l:occurences, i, 0)) > 1
				for [l:fx, l:fy] in l:occurences[i]
					let a:fieldsStatus[l:fy*s:colCount + l:fx] = 0
				endfor
			endif
			if ! has_key(l:occurences, i) || len(l:occurences[i]) > 1
				let l:compStatus[compIndex] = 0
			endif
		endfor
	endfor

	return l:compStatus
endfunction

function! s:updateHighlights(rowsStatus, colsStatus, boxesStatus, fieldsStatus)
	" Update row highlights
	call <SID>updateComponentHighlights(
				\ s:rowCount,
				\ s:rowHighlights,
				\ a:rowsStatus,
				\ 1,
				\ '<SID>highlightRow',
				\ {i -> i})

	" Update col highlights
	call <SID>updateComponentHighlights(
				\ s:colCount,
				\ s:colHighlights,
				\ a:colsStatus,
				\ 1,
				\ '<SID>highlightCol',
				\ {i -> i})

	" Update box highlights
	call <SID>updateComponentHighlights(
				\ s:boxCount,
				\ s:boxHighlights,
				\ a:boxesStatus,
				\ 1,
				\ '<SID>highlightBox',
				\ {i -> i})

	" Update highlights of duplicates
	call <SID>updateComponentHighlights(
				\ s:rowCount * s:colCount,
				\ s:dupHighlights,
				\ a:fieldsStatus,
				\ 0,
				\ '<SID>highlightField',
				\ {i -> [i % s:colCount, i / s:colCount]})
endfunction

function! s:updateComponentHighlights(size, highlights, status, hlReq, hlMethodRef, idxMap)
	for i in range(0, a:size - 1)
		if get(a:highlights, i, []) == [] && get(a:status, i, 1) == a:hlReq
			let a:highlights[i] = function(a:hlMethodRef)(a:idxMap(i))
		elseif get(a:highlights, i, []) != [] && get(a:status, i, 1) != a:hlReq
			for hl in a:highlights[i]
				call matchdelete(hl)
			endfor
			let a:highlights[i] = []
		endif
	endfor
endfunction

function! s:highlightRow(index)
	let [l:x, l:y] = <SID>mapFieldIndexToBufferPos([0, a:index])
	let l:bytes = s:width - 4

	return [matchaddpos("Valid", [[l:y, l:x, l:bytes]])]
endfunction

function! s:highlightCol(index)
	let [l:startX, l:startY] = <SID>mapFieldIndexToBufferPos([a:index, 0])
	let l:endY = <SID>mapFieldIndexToBufferPos([a:index, s:rowCount - 1])[1]
	let l:positions = []

	for y in range(l:startY, l:endY)
		let l:positions = add(l:positions, [y, l:startX, 1])
	endfor

	return [matchaddpos("Valid", l:positions[:((l:endY - l:startY) / 2)]),
		\ matchaddpos("Valid", l:positions[((l:endY - l:startY) / 2):])]
endfunction

function! s:highlightBox(index)
	let l:fieldIndex = [3 * (a:index % 3), 3 * (a:index / 3)]
	let [l:x, l:y] = <SID>mapFieldIndexToBufferPos(l:fieldIndex)
	let l:positions = []
	let l:bytes = 2*s:boxColCount - 1

	for i in range(0, s:boxRowCount - 1)
		let l:positions = add(l:positions, [l:y, l:x, l:bytes])
		let l:y += 1
	endfor

	return [matchaddpos("Valid", l:positions)]
endfunction

function! s:highlightField(index)
	let [l:x, l:y] = <SID>mapFieldIndexToBufferPos(a:index)
	return [matchaddpos("Invalid", [[l:y, l:x, 1]])]
endfunction

function! s:getOccurences(values, count, idxMap)
	let l:occurences = []

	for i in range(0, a:count - 1)
		let l:occurences = add(l:occurences, {})
		for v in range(1, 9)
			let l:occurences[i][v] = 0
		endfor
		for [l:x, l:y] in function(a:idxMap)(i)
			let l:val = a:values[l:y][l:x]
			if l:val >= 1 && l:val <= 9
				let l:occurences[i][l:val] = 1
			endif
		endfor
	endfor

	return l:occurences
endfunction

function! s:getPossibilities(values)
	let l:rowOccurences = <SID>getOccurences(
				\ a:values,
				\ s:rowCount,
				\ '<SID>getRowFieldIndexes')

	let l:colOccurences = <SID>getOccurences(
				\ a:values,
				\ s:colCount,
				\ '<SID>getColFieldIndexes')

	let l:boxOccurences = <SID>getOccurences(
				\ a:values,
				\ s:boxCount,
				\ '<SID>getBoxFieldIndexes')

	let l:possibilities = []
	for y in range(0, s:rowCount - 1)
		let l:possibilities = add(l:possibilities, [])
		for x in range(0, s:colCount - 1)
			if a:values[y][x] != '#'
				let l:possibilities[y] = add(l:possibilities[y], [])
				continue
			endif
			let l:possibilities[y] = add(l:possibilities[y], range(1, 9))
			call filter(l:possibilities[y][x], 'l:rowOccurences[y][v:val]==0')
			call filter(l:possibilities[y][x], 'l:colOccurences[x][v:val]==0')
			call filter(l:possibilities[y][x], 'l:boxOccurences[3*(y/3) + (x/3)][v:val]==0')
		endfor
	endfor

	return l:possibilities
endfunction

function! s:updatePossibilities(possibilities, pos, newVal)
	let l:idxs = []
	let l:idxs += <SID>getRowFieldIndexes(a:pos[1])
	let l:idxs += <SID>getColFieldIndexes(a:pos[0])
	let l:idxs += <SID>getBoxFieldIndexes(3*(a:pos[1] / 3) + (a:pos[0] / 3))

	for [x, y] in l:idxs
		call filter(a:possibilities[y][x], 'v:val != a:newVal')
	endfor

	return a:possibilities
endfunction

function! s:solve(values, ...)
	let l:possibilities = get(a:, 2, <SID>getPossibilities(a:values))

	" Find the field with least but non-zero possibilities.
	let [l:mx, l:my] = [-1, -1]
	let l:minNumOfPossibilities = 10
	for y in range(0, s:rowCount - 1)
		for x in range(0, s:colCount - 1)
			let l:numOfPossibilities = len(l:possibilities[y][x])
			if l:numOfPossibilities > 0 && l:numOfPossibilities < l:minNumOfPossibilities
				let [l:mx, l:my] = [x, y]
				let l:minNumOfPossibilities = l:numOfPossibilities
			endif
		endfor
	endfor

	if l:minNumOfPossibilities == 10 && s:isValid == 0
		return 0
	elseif l:minNumOfPossibilities == 10 && s:isValid == 1 && <SID>findNextEmptyField(a:values) == [-1, -1]
		return 1
	else
		for i in range(1, 9)
			let a:values[l:my][l:mx] = i
			call <SID>setFieldValue([l:mx, l:my], i)
			redraw
			call <SID>validate(a:values)
			if s:isValid == 0
				continue
			endif
			let l:ret = <SID>solve(a:values, <SID>updatePossibilities(l:possibilities, [l:mx, l:my], i))
			if l:ret == 1
				return 1
			endif
		endfor
		call <SID>setFieldValue([l:mx, l:my], '#')
		redraw
		return 0
	endif
endfunction

call <SID>init()

command Validate call <SID>validate(<SID>getValues())
command Solve call <SID>solve(<SID>getValues())
