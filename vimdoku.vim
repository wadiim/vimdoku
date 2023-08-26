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

	while l:x < s:colCount && l:y < s:rowCount && a:values[l:y][l:x] != '#'
		if l:x + 1 < s:colCount
			let l:x += 1
		else
			let l:y += 1
		endif
	endwhile

	return [l:x, l:y]
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

	let l:rowsStatus = {}
	for i in range(0, s:rowCount - 1)
		let l:rowsStatus[i] = 1
	endfor
	let l:colsStatus = copy(l:rowsStatus)
	let l:boxesStatus = copy(l:rowsStatus)
	let l:fieldsStatus = {}
	for i in range(0, s:rowCount*s:colCount - 1)
		let l:fieldsStatus[i] = 1
	endfor

	" Check horizontally
	for y in range(0, s:rowCount - 1)
		let l:occurences = {}
		for x in range(0, s:colCount - 1)
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
					let l:fieldsStatus[l:fy*s:colCount + l:fx] = 0
				endfor
			endif
			if ! has_key(l:occurences, i) || len(l:occurences[i]) > 1
				let l:rowsStatus[l:y] = 0
			endif
		endfor
	endfor

	" Check vertically
	for x in range(0, s:colCount - 1)
		let l:occurences = {}
		for y in range(0, s:rowCount - 1)
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
					let l:fieldsStatus[l:fy*s:colCount + l:fx] = 0
				endfor
			endif
			if ! has_key(l:occurences, i) || len(l:occurences[i]) > 1
				let l:colsStatus[l:x] = 0
			endif
		endfor
	endfor

	" Check boxes
	for boxIndex in range(0, s:boxCount - 1)
		let l:occurences = {}
		for fieldIndex in <SID>getBoxFieldIndexes(boxIndex)
			let [l:x, l:y] = fieldIndex
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
					let l:fieldsStatus[l:fy*s:colCount + l:fx] = 0
				endfor
			endif
			if ! has_key(l:occurences, i) || len(l:occurences[i]) > 1
				let l:boxesStatus[boxIndex] = 0
			endif
		endfor
	endfor

	call <SID>updateHighlights(l:rowsStatus, l:colsStatus, l:boxesStatus, l:fieldsStatus)
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

call <SID>init()

command Validate call <SID>validate(<SID>getValues())
