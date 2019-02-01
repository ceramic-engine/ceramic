if($('.post-content').hasClass('post-gallery')){
	$('img').on('click', function(e){
		var pswpElement = document.querySelectorAll('.pswp')[0];
		
		var items = [], images = [];
		images = $('.post-gallery img');
		$.each(images, function(index, image){
			items.push({
				src: image.src,
				w: image.naturalWidth,
				h: image.naturalHeight
			})
		});
		if(images){
			var options = {	index: images.index($(e.target)) };
			var gallery = new PhotoSwipe( pswpElement, PhotoSwipeUI_Default, items, options);
			gallery.init();
		}
	});	
}

