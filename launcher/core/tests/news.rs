use launcher_core::news::{parse, pick, BUILT_IN, FALLBACK_IMAGE};
use std::path::PathBuf;

fn ui_news(name: &str) -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../ui/news").join(name)
}

#[test]
fn built_in_news_parses_newest_first() {
    let items = parse(BUILT_IN).expect("launcher/news/news.json parses");
    assert!(items.len() >= 3, "the Play page shows three items");
    assert!(items.windows(2).all(|pair| pair[0].id > pair[1].id), "ids are unique");
    for item in &items {
        assert_eq!(item.date.len(), 10, "{}: date is YYYY-MM-DD", item.title);
        assert!(!item.title.is_empty() && !item.summary.is_empty() && !item.body.is_empty());
    }
}

#[test]
fn every_news_image_ships_with_the_launcher() {
    for item in parse(BUILT_IN).unwrap() {
        assert!(
            ui_news(&item.image).is_file(),
            "missing launcher/ui/news/{}",
            item.image
        );
    }
    assert!(ui_news(FALLBACK_IMAGE).is_file());
}

#[test]
fn broken_or_missing_feed_falls_back_to_the_built_in_copy() {
    let built_in = parse(BUILT_IN).unwrap();
    assert_eq!(pick(Err("offline".into()), |_| true), built_in);
    assert_eq!(pick(Ok("<html>404</html>".into()), |_| true), built_in);
    assert_eq!(pick(Ok("[]".into()), |_| true), built_in);
}

#[test]
fn fetched_news_wins_and_unknown_pictures_get_the_fallback() {
    let fetched = r#"[{"id": 9, "date": "2027-01-02", "kicker": "Dev update", "title": "New",
        "summary": "s", "body": "b", "image": "not_shipped_yet.jpg"}]"#;
    let items = pick(Ok(fetched.into()), |name| ui_news(name).is_file());
    assert_eq!(items.len(), 1);
    assert_eq!(items[0].title, "New");
    assert_eq!(items[0].image, FALLBACK_IMAGE);
}
