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

	let l:acmd = {}
	let l:acmd.bufnr = bufnr("%")
	let l:acmd.event = ['TextChanged', 'TextChangedI']
	let l:acmd.cmd = 'Validate'
	call autocmd_add([l:acmd])

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

function! s:mapFieldIndexToBufferPos(pos)
	let l:row = s:topOffset + a:pos[1] + (a:pos[1] / 3) + 2
	let l:col = s:leftOffset + 2*a:pos[0] + 2*(a:pos[0] / 3) + 3

	return [l:col, l:row]
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

function! s:Validate(values)
	" TODO: Add individual values validation testing if they belong to
	" 	the set of valid values, i.e. they are either '#' or
	" 	integers between 1 and 9.

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
	for i in range(0, s:rowCount - 1)
		if get(s:rowHighlights, i, 0) == 0 && get(a:rowsStatus, i, 1) == 1
			let s:rowHighlights[i] = <SID>highlightRow(i)
		elseif get(s:rowHighlights, i, 0) != 0 && get(a:rowsStatus, i, 1) == 0
			call matchdelete(s:rowHighlights[i])
			let s:rowHighlights[i] = 0
		endif
	endfor

	" Update col highlights
	for i in range(0, s:colCount - 1)
		if get(s:colHighlights, i, []) == [] && get(a:colsStatus, i, 1) == 1
			let s:colHighlights[i] = <SID>highlightCol(i)
		elseif get(s:colHighlights, i, []) != [] && get(a:colsStatus, i, 1) == 0
			call matchdelete(s:colHighlights[i][0])
			call matchdelete(s:colHighlights[i][1])
			let s:colHighlights[i] = []
		endif
	endfor

	" Update box highlights
	for i in range(0, s:boxCount - 1)
		if get(s:boxHighlights, i, 0) == 0 && get(a:boxesStatus, i, 1) == 1
			let s:boxHighlights[i] = <SID>highlightBox(i)
		elseif get(s:boxHighlights, i, 0) != 0 && get(a:boxesStatus, i, 1) == 0
			call matchdelete(s:boxHighlights[i])
			let s:boxHighlights[i] = 0
		endif
	endfor

	" Update highlights of duplicates
	for i in range(0, s:rowCount*s:colCount - 1)
		if get(s:dupHighlights, i, 0) == 0 && get(a:fieldsStatus, i, 1) == 0
			let s:dupHighlights[i] = <SID>highlightField(i % s:colCount, i / s:colCount)
		elseif get(s:dupHighlights, i, 0) != 0 && get(a:fieldsStatus, i, 1) == 1
			call matchdelete(s:dupHighlights[i])
			let s:dupHighlights[i] = 0
		endif
	endfor
endfunction

function! s:highlightRow(index)
	let [l:x, l:y] = <SID>mapFieldIndexToBufferPos([0, a:index])
	let l:bytes = s:width - 4

	return matchaddpos("Valid", [[l:y, l:x, l:bytes]])
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

	return matchaddpos("Valid", l:positions)
endfunction

function! s:highlightField(x, y)
	let [l:x, l:y] = <SID>mapFieldIndexToBufferPos([a:x, a:y])
	return matchaddpos("Invalid", [[l:y, l:x, 1]])
endfunction

call <SID>init()

command Validate call <SID>Validate(<SID>getValues())
