com -bar -buffer -range=% FoldSortBySize exe fold#md#sort#by_size(<line1>,<line2>)

let b:undo_ftplugin = get(b:, 'undo_ftplugin', 'exe').." | delc FoldSortBySize"

