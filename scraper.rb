require 'scraperwiki'
require 'mechanize'

# Extending Mechanize Form to support doPostBack
# http://scraperblog.blogspot.com.au/2012/10/asp-forms-with-dopostback-using-ruby.html
class Mechanize::Form
  def postback target, argument
    self['__EVENTTARGET'], self['__EVENTARGUMENT'] = target, argument
    submit
  end
end

def process_page(page, base_url, comment_url)
  page.search('tr.rgRow,tr.rgAltRow').each do |tr|
    record = {
      "council_reference" => tr.search('td')[1].inner_text.gsub("\r\n", "").strip,
      "address" => tr.search('td')[3].inner_html.gsub("\r", " ").strip.split("<br>")[0],
      "description" => tr.search('td')[3].inner_html.gsub("\r", " ").strip.split("<br>")[1],
      "info_url" => base_url + tr.search('td').at('a')["href"].to_s,
      "comment_url" => comment_url,
      "date_scraped" => Date.today.to_s,
      "date_received" => Date.parse(tr.search('td')[2].inner_text.gsub("\r\n", "").strip).to_s,
    }

    if (ScraperWiki.select("* from data where `council_reference`='#{record['council_reference']}'").empty? rescue true)
      puts "Saving record " + record['council_reference'] + " - " + record['address']
#       puts record
      ScraperWiki.save_sqlite(['council_reference'], record)
    else
      puts "Skipping already saved record " + record['council_reference']
    end
  end
end


case ENV['MORPH_PERIOD']
  when 'lastmonth'
    period = 'lastmonth'
  when 'thismonth'
    period = 'thismonth'
  else
    period = 'thisweek'
end
puts "Getting data in `" + period + "`, changable via MORPH_PERIOD variable"

base_url = "https://planning.mackay.qld.gov.au/masterview/Modules/Applicationmaster/"
url = base_url + "default.aspx?page=found&4a=443,444,445,446,487,555,556,557,558,559,560,564&6=F&1=" + period
comment_url = "mailto:development.services@mackay.qld.gov.au"

agent = Mechanize.new
page = agent.get(url)

if page.search('div.rgNumPart a').empty?
  process_page(page, base_url, comment_url)
else
  i = 1
  page.search('div.rgNumPart a').each do |a|
    puts "scraping page " + i.to_s
    target, argument = a[:href].scan(/'([^']*)'/).flatten
    page = page.form.postback target, argument

    process_page(page, base_url, comment_url)
    i += 1
  end
end
