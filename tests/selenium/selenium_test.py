from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
import time

service = Service(r"C:\chromedriver\chromedriver.exe")
driver = webdriver.Chrome(service=service)

# ① 打开首页
# url = "http://172.17.0.7:32755"
url = "http://localhost:8080/"
start = time.time()
driver.get(url)
print("首页加载时间:", time.time() - start)
driver.save_screenshot("step1_home.png")
time.sleep(1)

# ② 浏览商品（点击第一个商品）
product = driver.find_element(By.CSS_SELECTOR, ".hot-product-card a")
product.click()
driver.save_screenshot("step2_product_detail.png")
time.sleep(1)

# ③ 加入购物车
add_btn = driver.find_element(By.CSS_SELECTOR, ".cymbal-button-primary")
add_btn.click()
driver.save_screenshot("step3_add_cart.png")
time.sleep(1)

# ④ 进入购物车并下单
cart_btn = driver.find_element(By.CSS_SELECTOR, ".cart-link")
cart_btn.click()
driver.save_screenshot("step4_cart.png")
time.sleep(1)

checkout_btn = driver.find_element(By.XPATH, "//button[contains(text(),'Place Order')]")
checkout_btn.click()
driver.save_screenshot("step5_checkout.png")
time.sleep(1)

driver.find_element(By.CSS_SELECTOR, ".navbar-brand.d-flex.align-items-center").click()
time.sleep(1)
product = driver.find_element(By.CSS_SELECTOR, ".hot-product-card a")
product.click()
time.sleep(1)

# ⑤ 新增评价（Review Service）
# 等待并填写姓名
name_input = WebDriverWait(driver, 10).until(
    EC.presence_of_element_located((By.ID, "review-user-name"))
)
name_input.send_keys("Eric")
content_input = WebDriverWait(driver, 10).until(
    EC.presence_of_element_located((By.ID, "review-content"))
)
content_input.send_keys("This is a test review from Selenium.")
# review_input = driver.find_element(By.CSS_SELECTOR, "#review-text")
# review_input.send_keys("This is a test review from Selenium.")
driver.save_screenshot("step6_review_input.png")
time.sleep(1)

submit_btn = driver.find_element(By.XPATH, "//button[contains(text(),'Submit')]")
submit_btn.click()
driver.save_screenshot("step7_review_submit.png")
time.sleep(1)

driver.quit()
