import requests
from bs4 import BeautifulSoup
from urllib.parse import urljoin, urlparse
import re

def get_all_links(domain):
    urls = set()
    try:
        response = requests.get(domain)
        soup = BeautifulSoup(response.text, 'html.parser')
        for a_tag in soup.find_all('a', href=True):
            href = a_tag['href']
            full_url = urljoin(domain, href)
            if urlparse(full_url).netloc == urlparse(domain).netloc:
                urls.add(full_url)
    except Exception as e:
        print(f"Web scraping failed: {e}")
    return urls

def extract_chapter_info(url):
    chapter_match = re.search(r'ch(\d+)-(\d+)-', url)
    appendix_match = re.search(r'appendix-(\d+)', url)
    if chapter_match:
        return ('chapter', int(chapter_match.group(1)), int(chapter_match.group(2)))
    elif appendix_match:
        return ('end_appendix', int(appendix_match.group(1)))
    return ('other',)

def fetch_text_from_url(url):
    try:
        response = requests.get(url)
        soup = BeautifulSoup(response.text, 'html.parser')
        return soup.get_text()
    except Exception as e:
        print(f"Failed to fetch text from {url}: {e}")
        return ""

def clean_text(text):
    lines = text.splitlines()
    cleaned_lines = []
    empty_line_count = 0

    for line in lines:
        if line.strip() == "":
            empty_line_count += 1
        else:
            empty_line_count = 0
        if empty_line_count <= 3:
            cleaned_lines.append(line)

    return "\n".join(cleaned_lines)

if __name__ == "__main__":
    domains = ["book.cairo-lang.org", "book.starknet.io"]
    for domain in domains:
        urls = get_all_links(f"https://{domain}")
        
        # Extract chapter info and sort URLs
        sorted_urls = sorted(urls, key=lambda url: extract_chapter_info(url))
        
        # Fetch text and write to file
        with open(f"{domain}.txt", "w", encoding="utf-8") as file:
            for url in sorted_urls:
                file.write(f"URL: {url}\n")
                text = fetch_text_from_url(url)
                file.write(clean_text(text))
