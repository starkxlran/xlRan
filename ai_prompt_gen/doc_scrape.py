import requests
from bs4 import BeautifulSoup
from urllib.parse import urljoin, urlparse
import re

def get_all_links(domain):
    """
    Fetch all internal links from the given domain.

    Args:
        domain (str): The domain to scrape for links.

    Returns:
        set: A set of URLs found within the same domain.
    """
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

def extract_chapter_info(url, include_appendix=True, min_chapter=1, max_chapter=10):
    """
    Extract chapter or appendix information from a URL.

    Args:
        url (str): The URL to extract information from.
        include_appendix (bool): Whether to include appendix URLs.
        min_chapter (int): Minimum chapter number to include.
        max_chapter (int): Maximum chapter number to include.

    Returns:
        tuple: A tuple containing the type ('chapter', 'end_appendix', or 'other') and relevant numbers.
    """
    chapter_match = re.search(r'ch(\d+)-(\d+)-', url)
    appendix_match = re.search(r'appendix-(\d+)', url)
    if chapter_match:
        chapter_num = int(chapter_match.group(1))
        if min_chapter <= chapter_num <= max_chapter:
            return ('chapter', chapter_num, int(chapter_match.group(2)))
    elif appendix_match and include_appendix:
        return ('end_appendix', int(appendix_match.group(1)))
    return ('other',)

def fetch_text_from_url(url):
    """
    Fetch the text content from a given URL.

    Args:
        url (str): The URL to fetch text from.

    Returns:
        str: The text content of the page.
    """
    try:
        response = requests.get(url)
        soup = BeautifulSoup(response.text, 'html.parser')
        return soup.get_text()
    except Exception as e:
        print(f"Failed to fetch text from {url}: {e}")
        return ""

def clean_text(text):
    """
    Clean the text by removing excessive empty lines.

    Args:
        text (str): The text to clean.

    Returns:
        str: The cleaned text.
    """
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
        # Get all links from the domain
        urls = get_all_links(f"https://{domain}")
        
        # Filter URLs based on chapter info
        filtered_urls = [url for url in urls if extract_chapter_info(url)[0] != 'other']
        
        # Sort URLs based on chapter info
        sorted_urls = sorted(filtered_urls, key=lambda url: extract_chapter_info(url))

        # Fetch text and write to file
        with open(f"{domain}.txt", "w", encoding="utf-8") as file:
            for url in sorted_urls:
                file.write(f"URL: {url}\n")
                text = fetch_text_from_url(url)
                file.write(clean_text(text))
