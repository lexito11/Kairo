-- Media bucket: processed videos up to 300 MB.
update storage.buckets
set file_size_limit = 314572800
where id = 'media';
