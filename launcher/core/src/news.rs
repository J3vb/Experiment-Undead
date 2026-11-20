//! The launcher's news: a small JSON list kept in the repo (`launcher/news/news.json`). The
//! launcher asks for the copy on `main` so news shows without a launcher update, and falls
//! back to the copy built into it when offline or when the fetched one is broken.

use serde::{Deserialize, Serialize};
use std::time::Duration;

pub const NEWS_URL: &str = "https://raw.githubusercontent.com/J3vb/Experiment-Undead/main/launcher/news/news.json";
/// The news built into this launcher.
pub const BUILT_IN: &str = include_str!("../../news/news.json");
/// Picture shown for an item whose picture this launcher does not have.
pub const FALLBACK_IMAGE: &str = "kessel_dam.jpg";

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct NewsItem {
    /// Unique and only ever growing, so the News dot knows what is new.
    pub id: u32,
    /// `YYYY-MM-DD`.
    pub date: String,
    pub kicker: String,
    pub title: String,
    pub summary: String,
    pub body: String,
    /// A file name in `launcher/ui/news/`.
    pub image: String,
}

/// News items newest first, or an error when the text is not a non-empty news list.
pub fn parse(text: &str) -> Result<Vec<NewsItem>, String> {
    let mut items: Vec<NewsItem> = serde_json::from_str(text).map_err(|error| error.to_string())?;
    if items.is_empty() {
        return Err("The news list is empty.".into());
    }
    items.sort_by_key(|item| std::cmp::Reverse(item.id));
    Ok(items)
}

/// The fetched news when it parses, else the built-in copy. `known_image` says whether this
/// launcher ships a picture; unknown ones get the fallback picture.
pub fn pick(fetched: Result<String, String>, known_image: impl Fn(&str) -> bool) -> Vec<NewsItem> {
    let mut items = fetched
        .and_then(|text| parse(&text))
        .or_else(|_| parse(BUILT_IN))
        .unwrap_or_default();
    for item in &mut items {
        if !known_image(&item.image) {
            item.image = FALLBACK_IMAGE.into();
        }
    }
    items
}

/// Downloads the news list text.
pub fn fetch(url: &str) -> Result<String, String> {
    let client = reqwest::blocking::Client::builder()
        .user_agent(crate::feed::USER_AGENT)
        .timeout(Duration::from_secs(6))
        .build()
        .map_err(|error| error.to_string())?;
    let response = client.get(url).send().map_err(|error| error.to_string())?;
    if !response.status().is_success() {
        return Err(format!("The news server answered {}", response.status()));
    }
    response.text().map_err(|error| error.to_string())
}
