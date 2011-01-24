xml.instruct!
xml.feed "xmlns" => "http://www.w3.org/2005/Atom" do
	xml.title settings.site_title
	xml.updated @posts.first[:created_at].iso8601 if @posts.any?
	xml.author { xml.name settings.site_author }

	@posts.each do |post|
		xml.entry do
			xml.title post[:title]
			xml.link "rel" => "alternate", "href" => post.full_url
			xml.id post.full_url
			xml.published post[:created_at].iso8601
			xml.updated post[:created_at].iso8601
			xml.author { xml.name settings.site_author }
			xml.summary post.content, "type" => "html"
			xml.content post.content, "type" => "html"
		end
	end
end
